#!/usr/bin/env bash
# Install forklift: place the CLI on PATH and wire the OpenCode command.
# Mirrors sesh/mouth: --clone (git + symlink), --release (download), --uninstall.
# Requires at runtime: gh (authed), gpg, and txcript on PATH.
set -euo pipefail

REPO="${FORKLIFT_INSTALL_REPO:-pixincreate/forklift}"
REPO_URL_DEFAULT="https://github.com/${REPO}.git"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

mode="local"
version="${FORKLIFT_INSTALL_VERSION:-}"

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Install the forklift CLI and OpenCode command.

Options:
  --release     Download the latest GitHub release (requires the repo published)
  --clone       Clone the repo and symlink forklift + copy the command (updates via git pull)
  --uninstall   Remove forklift CLI and command
  --version X   Install release version X.Y.Z (default: latest)
  -h, --help    Show this help

  Env overrides:
    FORKLIFT_INSTALL_REPO       default: pixincreate/forklift
    FORKLIFT_INSTALL_BIN_DIR    default: ~/.local/bin
    FORKLIFT_INSTALL_OC_DIR     default: ~/.config/opencode
    FORKLIFT_INSTALL_REPO_DIR   default: ~/.local/share/forklift/repo
    FORKLIFT_INSTALL_CLI_SOURCE copy CLI from a local file instead of downloading
    FORKLIFT_INSTALL_COMMAND    set 0 to skip installing the /forklift command
    FORKLIFT_COMMAND_PATHS      space/comma list of command dirs (default: ~/.config/opencode/commands)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) mode="release"; shift ;;
    --clone) mode="clone"; shift ;;
    --uninstall) mode="uninstall"; shift ;;
    --version)
      if [[ -z "${2:-}" ]]; then echo "Error: --version requires a value" >&2; usage >&2; exit 1; fi
      version="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

home_dir="${HOME:?HOME is required}"
bin_dir="${FORKLIFT_INSTALL_BIN_DIR:-$home_dir/.local/bin}"
oc_dir="${FORKLIFT_INSTALL_OC_DIR:-$home_dir/.config/opencode}"
oc_cmd_dir="$oc_dir/commands"
state_dir="${FORKLIFT_INSTALL_REPO_DIR:-$home_dir/.local/share/forklift}"
repo_dir="$state_dir/repo"
repo_url="${FORKLIFT_INSTALL_REPO_URL:-$REPO_URL_DEFAULT}"
bin_target="$bin_dir/forklift"

# Best-effort: read the user's forklift.conf for command-install options.
forklift_conf="${XDG_CONFIG_HOME:-$home_dir/.config}/forklift/forklift.conf"
# shellcheck source=/dev/null
[ -r "$forklift_conf" ] && . "$forklift_conf" 2>/dev/null || true

log() { printf '%s\n' "$*"; }
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then echo "Error: required command not found: $1" >&2; exit 1; fi
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts"

# Install the /forklift command into one or more harness command dirs.
# Opt out with FORKLIFT_INSTALL_COMMAND=0. Target dirs come from
# FORKLIFT_COMMAND_PATHS (space/comma list); defaults to opencode's dir.
install_commands() {
  if [ "${FORKLIFT_INSTALL_COMMAND:-1}" = "0" ]; then
    log "Skipping command install (FORKLIFT_INSTALL_COMMAND=0)"
    return 0
  fi
  local src="${1:-}"
  [ -f "$src" ] || src="$ROOT/commands/forklift.md"
  [ -f "$src" ] || src="$repo_dir/commands/forklift.md"
  [ -f "$src" ] || { log "command template not found, skipping"; return 0; }
  local dirs="${FORKLIFT_COMMAND_PATHS:-$oc_cmd_dir}"
  local d
  for d in ${dirs//,/ }; do
    [ -z "$d" ] && continue
    mkdir -p "$d"
    cp "$src" "$d/forklift.md"
    log "Installed command to $d/forklift.md"
  done
}

install_local() {
  mkdir -p "$bin_dir"
  install -m 0755 "$SRC/forklift" "$bin_target"
  install_commands
  log "Installed forklift (local copy) to $bin_target"
}

install_release() {
  local v url
  mkdir -p "$bin_dir" "$oc_cmd_dir"
  if [[ -n "${FORKLIFT_INSTALL_CLI_SOURCE:-}" ]]; then
    cp "$FORKLIFT_INSTALL_CLI_SOURCE" "$bin_target"
  else
    require_command curl
    v="$version"; [[ -z "$v" ]] && v="$(latest_version)"
    url="https://raw.githubusercontent.com/${REPO}/v${v}/scripts/forklift"
    curl -fsSL "$url" -o "$bin_target"
  fi
  chmod +x "$bin_target"
  local tmp_cmd=""
  if [[ -n "$version" ]]; then
    tmp_cmd="$(mktemp)"
    curl -fsSL "https://raw.githubusercontent.com/${REPO}/v${version}/commands/forklift.md" -o "$tmp_cmd" || true
  fi
  install_commands "${tmp_cmd:-}"
  log "Installed forklift (release) to $bin_target"
}

install_clone() {
  require_command git
  if [[ -d "$repo_dir/.git" ]]; then
    git -C "$repo_dir" pull --ff-only
  else
    mkdir -p "$(dirname "$repo_dir")"
    git clone "$repo_url" "$repo_dir"
  fi
  mkdir -p "$bin_dir"
  ln -sf "$repo_dir/scripts/forklift" "$bin_target"
  install_commands
  log "Symlinked forklift to $bin_target (clone at $repo_dir)"
  log "Update later with: git -C $repo_dir pull"
}

uninstall() {
  rm -f "$bin_target"
  rm -f "$oc_cmd_dir/forklift.md"
  local d
  for d in ${FORKLIFT_COMMAND_PATHS//,/ }; do
    [ -z "$d" ] && continue
    rm -f "$d/forklift.md"
  done
  log "Removed $bin_target and the /forklift command(s)"
}

latest_version() {
  require_command curl
  curl -fsSL "$API_URL" | tr ',' '\n' | awk -F'"' '/"tag_name"/ { print $4; exit }' | sed 's/^v//'
}

case "$mode" in
  local) install_local ;;
  release) install_release ;;
  clone) install_clone ;;
  uninstall) uninstall ;;
esac

if [[ "$mode" != "uninstall" ]]; then
  if ! command -v txcript >/dev/null 2>&1; then
    log "NOTE: txcript not on PATH yet — install it (cargo install --git https://github.com/skillsynchq/txcript txcript-cli)"
  fi
  log "Ensure $bin_dir is on PATH, then: forklift init  (configure inbox), then: forklift send"
fi
