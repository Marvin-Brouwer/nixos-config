# shellcheck shell=bash
# `vscode-sync`. What it syncs, and why it works the way it does, is in
# default.nix. main, at the bottom, is the whole run in order; the steps are
# in sync.d/.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

: "${PREFIX:?}" "${EXTENSIONS_JSON_PY:?}"
# programs/tool/vscode-sync/plugins.nix, lowercased, one per line.
: "${BASE_EXTS?}"

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

MARKER_DIR="${HOME}/.config/nixos-vscode-sync"
# One marker, not one per repo. The installed set is global, so a per-repo
# marker would fast-path out on returning to a repo whose plugins another
# repo had since uninstalled.
MARKER_FILE="${MARKER_DIR}/installed.hash"
LOCK_FILE="${MARKER_DIR}/sync.lock"
LOG_FILE="${MARKER_DIR}/last.log"
mkdir -p "$MARKER_DIR"

# The steps, inlined here by lib/shell-script.nix when the command is built.
# shellcheck source=sync.d/settings.sh
. "$PARTS/settings.sh"
# shellcheck source=sync.d/desired.sh
. "$PARTS/desired.sh"
# shellcheck source=sync.d/lock.sh
. "$PARTS/lock.sh"
# shellcheck source=sync.d/install.sh
. "$PARTS/install.sh"

print_help() {
  cat <<HELP
usage: $PREFIX tool vscode-sync [--wait|--detach]

Makes the installed VSCode plugins (Windows and WSL side) equal the base list
in programs/tool/vscode-sync/plugins.nix plus this repo's .vscode/extensions.json.
Runs by itself on entering a repo with a mise.toml.

  (no option)  sync now, in the foreground
  --wait       wait for a sync the enter hook started
  --detach     sync in the background, logging to last.log
HELP
}

# Only act inside a repo this setup manages. Sets REPO_ROOT, REPO_NAME and
# EXT_FILE when it does.
#
# The enter hook lives in the system mise config, so mise fires it on every
# directory change anywhere on the box, not just in projects. Without this
# guard, a `cd /mnt/c` rewrites the extension set to match a directory that
# is not a project at all, silently uninstalling whatever the last real
# project had installed.
#
# A mise.toml is what marks a repo as managed here; `repoconfig` writes one.
# A sandboxed repo is one I do not trust, so its .vscode/extensions.json does
# not get to install plugins on the host. Its plugins live in the container.
skip_unless_managed_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    exit 0
  fi

  REPO_ROOT="$(repo_root)"
  if [ ! -f "$REPO_ROOT/mise.toml" ] && [ ! -f "$REPO_ROOT/.mise.toml" ]; then
    exit 0
  fi

  if [ "$(git -C "$REPO_ROOT" config --bool repoconfig.sandbox 2>/dev/null)" = true ]; then
    exit 0
  fi

  REPO_NAME="$(basename "$REPO_ROOT")"
  EXT_FILE="$REPO_ROOT/.vscode/extensions.json"
}

main() {
  case "${1:-}" in
    -h|--help) print_help; exit 0 ;;
  esac

  # --detach backgrounds the sync and logs instead of printing. The hook does
  # not use it: waiting and seeing the output is worth more than an instant
  # `cd`, given the fast path already makes an unchanged entry free.
  local detached=""
  if [ "${1:-}" = "--detach" ]; then
    detached=1
    shift
  fi

  if [ "${1:-}" = "--wait" ]; then
    wait_for_sync
    exit 0
  fi

  skip_unless_managed_repo
  want_plugins
  ensure_settings
  skip_if_installed

  [ -z "$detached" ] || detach "$@"
  take_lock

  FAIL=0
  if command -v cmd.exe >/dev/null 2>&1; then
    sync_windows
  fi
  if command -v code >/dev/null 2>&1; then
    sync_wsl
  fi
  record_result
}

main "$@"
