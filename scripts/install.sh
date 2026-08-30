#!/usr/bin/env bash
# Install forklift by symlinking it from this source dir into ~/.local/bin.
# Because it's a symlink, editing the source updates the command instantly —
# no reinstall, no copy, no clone. Run again (or git pull the source) to update.
set -euo pipefail

home_dir="${HOME:?HOME is required}"
bin_dir="$home_dir/.local/bin"
bin_target="$bin_dir/forklift"

mode="install"
no_command=0

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [--no-command] [--uninstall]

Symlinks forklift from this source checkout into ~/.local/bin (and, by
default, the /forklift OpenCode command). Updates are automatic: edit the
source here (or git pull it) and the symlink follows — no reinstall.

  --no-command   do not install the /forklift OpenCode command
  --uninstall    remove the symlinks
  -h, --help     show this help

Optional, set once in ~/.config/forklift/forklift.conf:
  FORKLIFT_INSTALL_COMMAND=0     skip the command install
  FORKLIFT_COMMAND_PATHS="d1 d2" install the command into several harness dirs

To install on a machine without this source:
  git clone https://github.com/pixincreate/forklift.git
  cd forklift && bash scripts/install.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) mode="uninstall"; shift ;;
    --no-command) no_command=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

forklift_conf="${XDG_CONFIG_HOME:-$home_dir/.config}/forklift/forklift.conf"
# shellcheck source=/dev/null
if [ -r "$forklift_conf" ]; then . "$forklift_conf" 2>/dev/null || true; fi

log() { printf '%s\n' "$*"; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts/forklift"

install_commands() {
  if [ "${FORKLIFT_INSTALL_COMMAND:-1}" = "0" ] || [ "$no_command" = "1" ]; then
    log "Skipping command install"
    return 0
  fi
  local src="$ROOT/commands/forklift.md"
  [ -f "$src" ] || { log "command template not found, skipping"; return 0; }
  local dirs="${FORKLIFT_COMMAND_PATHS:-$home_dir/.config/opencode/commands}"
  local d
  for d in ${dirs//,/ }; do
    [ -z "$d" ] && continue
    mkdir -p "$d"
    ln -sf "$src" "$d/forklift.md"
    log "Installed command to $d/forklift.md"
  done
}

install() {
  mkdir -p "$bin_dir"
  ln -sf "$SRC" "$bin_target"
  log "Symlinked forklift -> $bin_target"
  install_commands
}

uninstall() {
  rm -f "$bin_target"
  local d
  for d in ${FORKLIFT_COMMAND_PATHS//,/ } "$home_dir/.config/opencode/commands"; do
    [ -z "$d" ] && continue
    rm -f "$d/forklift.md"
  done
  log "Removed $bin_target and the /forklift command(s)"
}

if [ "$mode" = "uninstall" ]; then
  uninstall
else
  install
  if ! command -v txcript >/dev/null 2>&1; then
    log "NOTE: txcript not on PATH yet - install it (cargo install --git https://github.com/skillsynchq/txcript txcript-cli)"
  fi
  log "Ensure $bin_dir is on PATH, then: forklift init  (configure inbox), then: forklift send"
fi
