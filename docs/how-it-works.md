# How it works

forklift moves a session in four steps: export, encrypt, drop, pull.

## Pipeline

```
send    txcript export <id> --from <harness>
        → prepend a one-line meta (session id + git state)
        → gpg-encrypt with token + salt (AES-256)   → <token>.gpg
        → pushed straight into the inbox (no temp files)

receive fetch the blob from the inbox
        → gpg-decrypt            → split meta line + Simple doc
        → compare meta git commit vs local HEAD (warns on mismatch)
        → txcript continue - --with <harness> --no-resume
        → the blob is deleted from the inbox (auto-clean)
```

## The code and the key

- The **code** is `GID.TOKEN` (gist) or just `TOKEN` (git/github inbox).
  - `GID` is the gist id — where the blob lives.
  - `TOKEN` is one half of the gpg passphrase.
- The other half is your local **salt** (`FORKLIFT_SALT`), which never leaves
  the machine. Passphrase = `TOKEN + SALT`. A leaked blob is useless without
  the salt.
- Nothing is written to disk in plaintext. The export is piped into gpg and into
  the inbox; `receive` pipes it back into gpg and `txcript continue -`. The only
  on-disk artifact is the encrypted ciphertext in the inbox (and, for the git
  backend, a throwaway clone that is deleted).

## Backends

`FORKLIFT_INBOX_REPO` selects where blobs live:

- unset / `gist` → a secret GitHub Gist (default). No repo to create.
- `owner/name` → a private GitHub repo, via the gh API.
- any git URL (git@, https://, file://) → a throwaway clone; no persistent
  local file.

## What forklift is not (scope)

- **Bidirectional sync:** forklift is one-way. You fork A → B; afterwards the
  two sessions diverge. It does not keep both machines in lockstep.
- **Persistent pairing:** there is no remembered link between machines. Every
  transfer needs a fresh code.
- **Session picker:** `send` takes the latest session or an explicit id. There
  is no interactive menu to choose from many.
- **`--sanitize`:** no option to strip secrets/paths from the export. The trust
  model is me→me, so the raw export is sent.
- **Other transports:** only gist / git / github backends exist. No IPFS, S3,
  etc.
- **Preserving the original session id:** the received session is a *new* id (a
  fork). That is the point — not a bug.
