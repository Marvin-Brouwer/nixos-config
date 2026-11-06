# shellcheck shell=bash
# `vscode-sync`. What it syncs, and why it works the way it does, is in
# default.nix.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

: "${PREFIX:?}" "${EXTENSIONS_JSON_PY:?}"
# programs/vscode-plugins.nix, lowercased, one per line.
: "${BASE_EXTS?}"

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

MARKER_DIR="${HOME}/.config/nixos-vscode-sync"
LOCK_FILE="${MARKER_DIR}/sync.lock"
LOG_FILE="${MARKER_DIR}/last.log"
mkdir -p "$MARKER_DIR"

case "${1:-}" in
  -h|--help)
    cat <<HELP
usage: $PREFIX vscode-sync [--wait|--detach]

Makes the installed VSCode plugins (Windows and WSL side) equal the base list
in programs/vscode-plugins.nix plus this repo's .vscode/extensions.json.
Runs by itself on entering a repo with a mise.toml.

  (no option)  sync now, in the foreground
  --wait       wait for a sync the enter hook started
  --detach     sync in the background, logging to last.log
HELP
    exit 0 ;;
esac

# --detach backgrounds the sync and logs instead of printing. The hook does
# not use it: waiting and seeing the output is worth more than an instant
# `cd`, given the fast path already makes an unchanged entry free.
DETACH=""
if [ "${1:-}" = "--detach" ]; then
  DETACH=1
  shift
fi

# `vscode-sync --wait` blocks until a sync started by the hook has finished,
# so there is something to run before opening VSCode rather than guessing
# from scrollback.
if [ "${1:-}" = "--wait" ]; then
  if ! flock -n "$LOCK_FILE" true; then
    echo "[vscode] Waiting for the running sync to finish..."
  fi
  flock "$LOCK_FILE" true
  echo "[vscode] Sync idle."
  [ -s "$LOG_FILE" ] && echo "[vscode] Last detached run: $LOG_FILE"
  exit 0
fi

# Only act inside a repo this setup manages.
#
# The enter hook lives in the system mise config, so mise fires it on every
# directory change anywhere on the box, not just in projects. Without this
# guard, a `cd /mnt/c` rewrites the extension set to match a directory that
# is not a project at all, silently uninstalling whatever the last real
# project had installed.
#
# A mise.toml is what marks a repo as managed here; `repoconfig` writes one.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

REPO_ROOT="$(repo_root)"
if [ ! -f "$REPO_ROOT/mise.toml" ] && [ ! -f "$REPO_ROOT/.mise.toml" ]; then
  exit 0
fi

# A sandboxed repo is one I do not trust, so its .vscode/extensions.json does
# not get to install plugins on the host. Its plugins live in the container.
if [ "$(git -C "$REPO_ROOT" config --bool repoconfig.sandbox 2>/dev/null)" = true ]; then
  exit 0
fi

REPO_NAME="$(basename "$REPO_ROOT")"
EXT_FILE="$REPO_ROOT/.vscode/extensions.json"

# One marker, not one per repo. The installed set is global, so a per-repo
# marker would fast-path out on returning to a repo whose plugins another
# repo had since uninstalled.
MARKER_FILE="${MARKER_DIR}/installed.hash"

# The steps, inlined here by lib/shell-script.nix when the command is built.
# Each part carries on where the previous one stopped.
# shellcheck source=sync.d/settings.sh
. "$PARTS/settings.sh"

# shellcheck source=sync.d/desired.sh
. "$PARTS/desired.sh"

# shellcheck source=sync.d/lock.sh
. "$PARTS/lock.sh"

# shellcheck source=sync.d/windows.sh
. "$PARTS/windows.sh"

# shellcheck source=sync.d/wsl.sh
. "$PARTS/wsl.sh"

# shellcheck source=sync.d/record.sh
. "$PARTS/record.sh"
