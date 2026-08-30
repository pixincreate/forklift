#!/usr/bin/env bash
# Install forklift: put the CLI on PATH and (optionally) wire the OpenCode command.
# Modes: --clone (git + symlink, updates via git pull), --local (copy from checkout),
#        --uninstall.
# Requires at runtime: gh (authed), gpg, and txcript on PATH.
set -euo pipefail

REPO="pixincreate/forklift"
REPO_URL="https://github.com/${REPO}.git"
home_dir="${HOME:?HOME is required}"
bin_dir="$home_dir/.local/bin"
state_dir="$home_dir/.local/share/forklift"
repo_dir="$state_dir/repo"
bin_target="$bin_dir/forklift"

mode="local"
no_command=0

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [mode]

Modes:
  --clone       Clone the repo and symlink forklift (update later: git -C ~/.local/share/forklift/repo pull)
  --local       Copy the CLI from this checkout (default)
  --uninstall   Remove forklift CLI and command
  --no-command  Do not install the /forklift OpenCode command
  -h, --help    Show this help

Optional, set once in ~/.config/forklift/forklift.conf:
  FORKLIFT_INSTALL_COMMAND=0       skip the command install
  FORKLIFT_COMMAND_PATHS="d1 d2"   install the command into several harness dirs
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clone) mode="clone"; shift ;;
    --local) mode="local"; shift ;;
    --uninstall) mode="uninstall"; shift ;;
    --no-command) no_command=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Read optional overrides from forklift.conf (set once, never on the command line).
forklift_conf="${XDG_CONFIG_HOME:-$home_dir/.config}/forklift/forklift.conf"
# shellcheck source=/dev/null
if [ -r "$forklift_conf" ]; then . "$forklift_conf" 2>/dev/null || true; fi

log() { printf '%s\n' "$*"; }
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then echo "Error: required command not found: $1" >&2; exit 1; fi
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts"

# Install the /forklift command into one or more harness command dirs.
# Opt out with --no-command or FORKLIFT_INSTALL_COMMAND=0 in forklift.conf.
install_commands() {
  if [ "${FORKLIFT_INSTALL_COMMAND:-1}" = "0" ] || [ "$no_command" = "1" ]; then
    log "Skipping command install"
    return 0
  fi
  local src="$ROOT/commands/forklift.md"
  [ -f "$src" ] || { log "command template not found, skipping"; return 0; }
  local dirs="${FORKLIFT_COMMAND_PATHS:-$home_dir/.config/opencode/commands}"
  local d action="cp -f"
  [ "$mode" = "clone" ] && action="ln -sf"
  for d in ${dirs//,/ }; do
    [ -z "$d" ] && continue
    mkdir -p "$d"
    $action "$src" "$d/forklift.md"
    log "Installed command to $d/forklift.md"
  done
}

install_local() {
  mkdir -p "$bin_dir"
  install -m 0755 "$SRC/forklift" "$bin_target"
  install_commands
  log "Installed forklift (local copy) to $bin_target"
}

install_clone() {
  require_command git
  if [[ -d "$repo_dir/.git" ]]; then
    git -C "$repo_dir" pull --ff-only
  else
    mkdir -p "$(dirname "$repo_dir")"
    git clone "$REPO_URL" "$repo_dir"
  fi
  mkdir -p "$bin_dir"
  ln -sf "$repo_dir/scripts/forklift" "$bin_target"
  install_commands
  log "Symlinked forklift to $bin_target (clone at $repo_dir)"
  log "Update later with: git -C $repo_dir pull"
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

case "$mode" in
  local) install_local ;;
  clone) install_clone ;;
  uninstall) uninstall ;;
esac

if [[ "$mode" != "uninstall" ]]; then
  if ! command -v txcript >/dev/null 2>&1; then
    log "NOTE: txcript not on PATH yet - install it (cargo install --git https://github.com/skillsynchq/txcript txcript-cli)"
  fi
  log "Ensure $bin_dir is on PATH, then: forklift init  (configure inbox), then: forklift send"
fi
