# Security

forklift's threat model is **me → me**: you are moving your own session between
your own machines.

- **Encryption:** the blob is gpg AES-256, passphrase = `TOKEN + SALT`. The
  `TOKEN` half travels in the code; the `SALT` half lives only in
  `~/.config/forklift/forklift.conf` on each machine and is never uploaded. An
  exposed gist/blob cannot be decrypted without the salt. Set the same salt on
  both machines.
- **No plaintext at rest:** the session is never written to disk unencrypted.
  It is piped export → gpg → inbox, and on receive piped inbox → gpg →
  `txcript continue -`.
- **No overwriting:** `receive` always creates a fresh fork
  (`txcript continue --no-resume`). It never clobbers an existing session.
- **Auto-clean:** the blob is deleted from the inbox as soon as it is received.
- **The inbox is yours:** it is a gist or repo you control. forklift never
  hardcodes a third party's storage.
