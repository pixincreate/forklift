# forklift

> move your AI session to the next machine without throwing out your back.

Fork an OpenCode session to another machine — and optionally into another coding
agent — in one command. No more manual `export` → messaging app → `import`.

`forklift` is the command; `forklift` is the GitHub/npm package
(mirroring [`opencode-global-sessions`](https://github.com/pixincreate/opencode-global-sessions) / `sesh`).

## Why

You start a session on one machine and want to keep going on another. OpenCode's
`--fork` already continues a session as a new one _locally_; `forklift` does that
**across machines**. The receiving side gets a fresh session built from the
exported transcript, then diverges from there (commands, tool outputs, and files
stay machine-local on whichever side runs them).

Because the transfer unit is [txcript](https://github.com/skillsynchq/txcript)'s
harness-agnostic "Simple" document, the receiving side can land the session in
OpenCode **or** any other harness txcript supports (Claude Code, Codex, Cursor, …).

## Install

Prerequisites on every machine:

- [`txcript`](https://github.com/skillsynchq/txcript) on your `PATH` (e.g. `cargo install --git https://github.com/skillsynchq/txcript txcript-cli`)
- `gpg` and `openssl`
- `gh` authenticated (`gh auth login`) — the default inbox is a **GitHub Gist** (a secret, unlisted gist); no repo to create
- For an alternative inbox: `git` plus any git remote URL (https/ssh/file://), or `owner/name` for a private GitHub repo inbox

Install the CLI — pick one:

```sh
# Primary (no npm): clone + symlink; updates via git pull
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pixincreate/forklift/master/scripts/install.sh)" -- --clone
```

```sh
# Alternative — npm, no npmjs account (installs from the GitHub repo)
npm install -g github:pixincreate/forklift
```

The curl|bash form clones the repo to `~/.local/share/forklift/repo`,
symlinks `forklift` to `~/.local/bin/`, and copies the `/forklift` command file into
`~/.config/opencode/commands/`. Update later with:

```sh
git -C ~/.local/share/forklift/repo pull
```

(Or just re-run the curl line.) The npm form puts `forklift` on `PATH` via the
`bin` entry and drops the command file via `postinstall`. Either way the tool is
config-driven and safe to publish — no private paths are hardcoded.

Then configure the inbox once per machine:

```sh
forklift init          # gist is the default; prompts for a salt, writes ~/.config/forklift/forklift.conf
```

`forklift init` picks **GitHub Gist** by default (no repo to create — it uses
your already-authed `gh`). You can instead point `FORKLIFT_INBOX_REPO` at a
private `owner/name` GitHub repo or any git URL. It also asks for a **salt**:
a local-only string mixed into the encryption key. The salt is stored only in
`~/.config/forklift/forklift.conf` and never leaves the machine — so even if a
gist is exposed, it cannot be decrypted without the salt. Set the same salt on
both machines.

## Usage

On the source machine:

```sh
forklift send                 # forks the latest session (harness: opencode)
forklift send --from claude_code   # or export from another harness txcript supports
forklift send <id>            # or a specific session id
forklift send --file doc.json # or a pre-exported txcript "Simple" doc
```

It prints a code, e.g.:

```
code:  a1b2c3d4e5f6
On the other machine, run:
  forklift receive a1b2c3d4e5f6
```

On the destination machine:

```sh
forklift receive a1b2c3d4e5f6            # forks into OpenCode
forklift receive a1b2c3d4e5f6 claude_code  # or into another harness
```

Inside OpenCode you can also run `/forklift` (bare = send) and
`/forklift receive <code>` (with optional `<harness>`).

## How it works

```
send    txcript export <id> --from <harness>
        → prepend a one-line meta (session id + git state)
        → gpg-encrypt with a random token (AES-256)   → <token>.gpg
        → pushed straight into the inbox (no temp files)

receive fetch <token>.gpg from the inbox
        → gpg-decrypt            → split meta line + Simple doc
        → compare meta git commit vs local HEAD (warns on mismatch)
        → txcript continue - --with <harness> --no-resume
        → the blob is deleted from the inbox (auto-clean)
```

- The **code** is `GID.TOKEN` (gist) or just `TOKEN` (git/github inbox). The
  token is one half of the gpg passphrase; the other half is your local **salt**
  (`FORKLIFT_SALT`), which never leaves the machine. A leaked inbox blob is
  useless without the salt, so the gist living on GitHub is not a risk.
- **Nothing is written to disk in plaintext.** The export is piped straight into
  gpg and straight into the inbox; `receive` pipes the blob straight into gpg and
  into `txcript continue -`. The only thing on disk is the encrypted ciphertext
  in the inbox repo (and, briefly, in a throwaway git clone that is deleted).
- The meta line records the git commit, branch, and machine so `receive` can warn
  when the two sides are on different commits.
- The inbox repo is private; overwriting never happens — `txcript continue
--no-resume` always writes a fresh fork.

## Security

- Me→me trust model: raw export by default (no `--sanitize`).
- The gpg passphrase is `token + salt`. The salt lives only in your local
  `~/.config/forklift/forklift.conf` and is never uploaded, so an exposed inbox
  blob cannot be decrypted by anyone without the salt.
- The blob is gpg-encrypted with a random passphrase; the private gist/repo
  hides the ciphertext, gpg adds defense-in-depth.
- No plaintext session file is ever written to the local machine.
- `receive` never overwrites: `txcript continue --no-resume` always writes a fresh fork.

## Develop

```sh
shellcheck -e SC2016 scripts/forklift scripts/install.sh tests/test.sh
bash tests/test.sh     # offline: uses a local git "inbox", no GitHub/txcript needed
```

## Out of scope (v1)

Bidirectional sync, persistent pairing, a session picker, `--sanitize`, other
transports, and preserving the original session id (the new session is meant to
be new).
