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
cmd_target="$oc_cmd_dir/forklift.md"

log() { printf '%s\n' "$*"; }
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then echo "Error: required command not found: $1" >&2; exit 1; fi
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/scripts"

install_local() {
  mkdir -p "$bin_dir" "$oc_cmd_dir"
  install -m 0755 "$SRC/forklift" "$bin_target"
  cp "$ROOT/commands/forklift.md" "$cmd_target"
  log "Installed forklift (local copy) to $bin_target"
  log "OpenCode command: $cmd_target"
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
  if [[ -n "$version" ]]; then
    curl -fsSL "https://raw.githubusercontent.com/${REPO}/v${version}/commands/forklift.md" -o "$cmd_target" || true
  fi
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
  mkdir -p "$bin_dir" "$oc_cmd_dir"
  ln -sf "$repo_dir/scripts/forklift" "$bin_target"
  cp "$repo_dir/commands/forklift.md" "$cmd_target"
  log "Symlinked forklift to $bin_target (clone at $repo_dir)"
  log "Update later with: git -C $repo_dir pull"
}

uninstall() {
  rm -f "$bin_target"
  rm -f "$cmd_target"
  log "Removed $bin_target and $cmd_target"
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
