# forklift

> move your AI session to the next machine without throwing out your back.

## introduction

You start a session on one machine and want to keep going on another. OpenCode's
`--fork` continues a session as a new one *locally*; forklift does that
**across machines**. The receiving side gets a fresh session built from the
exported transcript, then diverges (commands, tool outputs, and files stay
machine-local on whichever side runs them).

The transfer unit is [txcript](https://github.com/skillsynchq/txcript)'s
harness-agnostic "Simple" document, so the receiving side can land the session
in OpenCode **or** any other harness txcript supports (Claude Code, Codex,
Cursor, …).

## lore

forklift exists because moving a session between machines used to mean: export
the JSON here, push it through a messaging app (Signal, etc.), import it on the
other machine. Too much friction for something that should be one command.

It is named after a forklift on purpose: it picks up a running session, carries
it across the room (or the continent), and sets it down somewhere else to keep
working. The new session is a *fork* — a continuation, not a mirror.

## install

Prerequisites on every machine:

- [`txcript`](https://github.com/skillsynchq/txcript) on your `PATH` (`cargo install --git https://github.com/skillsynchq/txcript txcript-cli`)
- `gpg` and `openssl`
- `gh` authenticated (`gh auth login`) — the default inbox is a secret GitHub Gist; no repo to create
- For an alternative inbox: `git` plus any git remote URL, or `owner/name` for a private GitHub repo inbox

Install the CLI:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/pixincreate/forklift/master/scripts/install.sh)" -- --clone
```

This clones the repo to `~/.local/share/forklift/repo`, symlinks `forklift` to
`~/.local/bin/`, and (unless disabled) drops the `/forklift` command file into
`~/.config/opencode/commands`. Update later with
`git -C ~/.local/share/forklift/repo pull`.

Then configure the inbox once per machine:

```sh
forklift init          # gist is the default; prompts for a secret
```

`forklift init` picks GitHub Gist by default (uses your already-authed `gh`).
You can instead point `FORKLIFT_INBOX_REPO` at a private `owner/name` GitHub
repo or any git URL. It also asks for a **secret** — a local-only string mixed
into the encryption key, stored only in `~/.config/forklift/forklift.conf` and
never transmitted. Set the same secret on both machines.

### command install (optional)

By default the installer also drops the `/forklift` OpenCode command into
`~/.config/opencode/commands`. If you manage commands yourself (e.g. through
`skillset` + `capsync`), skip it with `--no-command`:

```sh
bash scripts/install.sh --clone --no-command
```

or set it once in `~/.config/forklift/forklift.conf`:

```
FORKLIFT_INSTALL_COMMAND=0
```

To install into several harness command dirs at once, add a list to
`~/.config/forklift/forklift.conf`:

```
FORKLIFT_COMMAND_PATHS="/home/you/.config/opencode/commands /home/you/.claude/commands"
```

## usage

On the source machine:

```sh
forklift send                 # fork the latest session (harness: opencode)
forklift send --from claude_code   # or export from another harness
forklift send <id>            # or a specific session id
forklift send --file doc.json # or a pre-exported txcript "Simple" doc
```

It prints a code, e.g.:

```
code:  GID.TOKEN
On the other machine, run:
  forklift receive GID.TOKEN
```

On the destination machine:

```sh
forklift receive GID.TOKEN              # fork into OpenCode
forklift receive GID.TOKEN claude_code  # or into another harness
```

Inside OpenCode you can also run `/forklift` (bare = send) and
`/forklift receive <code>`.

For the internals and the security model, see
[docs/how-it-works.md](docs/how-it-works.md) and
[docs/security.md](docs/security.md).

## uninstall

```sh
bash scripts/install.sh --uninstall
```

This removes the symlinked/copied `forklift` CLI and the `/forklift` command
file. It does **not** touch your `~/.config/forklift/forklift.conf` or any
gists you created — remove those by hand if you want them gone.

## contribution

forklift is a small, focused tool. Contributions welcome, but keep it that way:

- One purpose: move a session between machines with harness conversion.
- No new dependencies, no new backends without a real need.
- Run the checks before opening a PR:

```sh
shellcheck -e SC2016 scripts/forklift scripts/install.sh tests/test.sh
bash tests/test.sh
```

## credit

- [txcript](https://github.com/skillsynchq/txcript) by
  [skillsynchq](https://github.com/skillsynchq) — the harness-agnostic session
  translator that makes cross-harness forking possible.
- [opencode-global-sessions (sesh)](https://github.com/pixincreate/opencode-global-sessions)
  — the install/distribution pattern forklift borrows.
- `gpg` and GitHub Gist — the encryption and transport primitives.

## license

Released under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
— public domain dedication. No rights reserved.
