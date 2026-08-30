#!/usr/bin/env bash
# Tests for forklift's transport contract: encrypt -> push -> pull -> decrypt roundtrip,
# plus the readable commit message and metadata. Runs fully offline against a local
# bare git "inbox" (no GitHub, no opencode, no txcript required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/forklift-test.XXXXXX")"
trap 'rm -r "$TMP"' EXIT

INBOX="$TMP/inbox.git"
git init --bare "$INBOX" >/dev/null
export FORKLIFT_INBOX_REPO="file://$INBOX"
export XDG_CONFIG_HOME="$TMP/cfg"
export FORKLIFT_OWNER=testuser

# txcript stub: `continue` consumes stdin (the Simple doc) and does nothing,
# keeping the offline test free of real harnesses.
STUB="$TMP/txcript"
cat > "$STUB" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  continue) cat >/dev/null;;
  list) echo "opencode 2026 ses_testabc123 Refactor the billing service";;
  export) :;;
esac
EOF
chmod +x "$STUB"
export TXCRIPT="$STUB"

# shellcheck source=scripts/forklift
source "$ROOT/scripts/forklift"

pass=0; fail=0
assert() { # assert <description> <shell-condition-in-single-quotes>
  if eval "$2"; then echo "  ok  - $1"; pass=$((pass+1)); else echo "  FAIL- $1"; fail=$((fail+1)); fi
}

FIXTURE="$TMP/session.simple.json"
cat > "$FIXTURE" <<'JSON'
{
  "id": "ses_testabc123",
  "title": "Refactor the billing service",
  "cwd": "/home/dev/billing",
  "timestamp": "2026-08-12T10:00:00Z",
  "messages": [{"role": "user", "content": "hello"}]
}
JSON

echo "forklift transport tests"

# 1. send a fixture doc -> returns a code, pushes an ENCRYPTED blob, commits with the title
out="$(cmd_send --file "$FIXTURE")"
token="$(printf '%s' "$out" | awk '/^code:/{print $2}')"
assert 'send prints a code' '[ -n "$token" ]'
assert 'blob pushed to inbox' 'git --git-dir="$INBOX" cat-file -e "master:forklift/$token.gpg" >/dev/null 2>&1'
# the at-rest blob must be ciphertext, not the plain JSON
assert 'blob is encrypted at rest' 'test "$(git --git-dir="$INBOX" cat-file -p "master:forklift/$token.gpg" | head -c1)" != "{"'
# shellcheck disable=SC2034  # subject is referenced only inside eval'd assert conditions
subject="$(git --git-dir="$INBOX" log -1 --pretty=%s)"
assert 'commit subject names the session' 'printf "%s" "$subject" | grep -q "Refactor the billing service"'
assert 'commit subject carries the session id' 'printf "%s" "$subject" | grep -q "ses_testabc"'

# 2. decrypt roundtrip - recovered doc equals what we sent; meta carried in first line
plain="$(git --git-dir="$INBOX" cat-file -p "master:forklift/$token.gpg" \
  | gpg --batch --yes --pinentry-mode loopback --decrypt --passphrase "$token" 2>/dev/null)"
meta_line="$(printf '%s\n' "$plain" | sed -n '1p')"
doc="$(printf '%s\n' "$plain" | tail -n +2)"
assert 'decrypted doc matches original' 'diff <(printf "%s\n" "$doc" | jq -S .) <(jq -S . "$FIXTURE") >/dev/null'
assert 'meta line records the session id' 'printf "%s" "$meta_line" | jq -r .sessionId | grep -q "ses_testabc"'

# 3. send must not write a plaintext session file anywhere
assert 'no plaintext session file written by send' \
  'test "$(find "$TMP" -name "session.simple.json" -not -path "$FIXTURE" | wc -l)" -eq 0'

# 4. wrong code fails cleanly, leaves no side effect
if ( cmd_receive "deadbeefdead" >/dev/null 2>&1 ); then
  assert 'bad code is rejected' 'false'
else
  assert 'bad code is rejected' 'true'
fi

# 5. receive wipes the blob from the inbox so it does not linger
FIX2="$TMP/session2.simple.json"
cat > "$FIX2" <<'JSON'
{"id":"ses_wipe2","title":"Second fixture","cwd":"/x","timestamp":"2026-08-30T00:00:00Z","messages":[{"role":"user","content":"hi"}]}
JSON
out2="$(cmd_send --file "$FIX2")"
tok2="$(printf '%s' "$out2" | awk '/^code:/{print $2}')"
cmd_receive "$tok2" >/dev/null 2>&1
assert 'blob removed from inbox after receive' \
  '! git --git-dir="$INBOX" cat-file -e "master:forklift/$tok2.gpg" >/dev/null 2>&1'
assert 'inbox records the wipe commit' \
  'test -n "$(git --git-dir="$INBOX" log --grep="removed from inbox" --pretty=%s)"'

# 6. receive search: fuzzy-match by name, pick from the list, then pull + wipe
# shellcheck disable=SC2034  # search_out is consumed by the grep assertion below
search_out="$(echo 1 | cmd_search "refactor" opencode)"
assert 'search finds the session by name' 'printf "%s" "$search_out" | grep -q "Refactor the billing service"'
assert 'search-selected blob removed from inbox' \
  '! git --git-dir="$INBOX" cat-file -e "master:forklift/$token.gpg" >/dev/null 2>&1'

# 7. search with no match is rejected cleanly
if ( cmd_search "zzznomatch" opencode >/dev/null 2>&1 ); then
  assert 'search with no match is rejected' 'false'
else
  assert 'search with no match is rejected' 'true'
fi

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
