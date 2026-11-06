# shellcheck shell=bash
# The `repoconfig` command.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${PREFIX:?}" "${USAGE:?}" "${GIT_USER_NAME:?}" "${LIST_FILE:?}"
: "${PRESETS_DIR:?}" "${PRESET_NAMES:?}" "${SANDBOX_CHECK:?}"

# --sandbox may go anywhere; the rest is positional.
SANDBOX=
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --sandbox) SANDBOX=1 ;;
    *) ARGS+=("$arg") ;;
  esac
done
PRESET="${ARGS[0]:-}"
EMAIL="${ARGS[1]:-}"

say()  { printf '   %s\n' "$*"; }
made() { printf '   \033[1;32mcreated\033[0m %s\n' "$*"; }
kept() { printf '   \033[1;33mkept\033[0m    %s (already present)\n' "$*"; }
die()  { printf '\033[1;31mrepoconfig:\033[0m %s\n' "$*" >&2; exit 1; }

case "$PRESET" in
  -h|--help)
    # shellcheck source=repoconfig.d/help.sh
    . "$PARTS/help.sh"
    exit 0 ;;
  -l|--list) cat "$LIST_FILE"; exit 0 ;;
esac

# One directory per preset, built by default.nix: mise.toml, extensions.json,
# devcontainer.json, and files/ for anything else the preset writes. Looked up
# by name rather than by path, so an argument like ../ cannot point it anywhere.
read -ra PRESETS <<< "$PRESET_NAMES"
PRESET_DIR=
for name in "${PRESETS[@]}"; do
  [ "$name" = "$PRESET" ] && PRESET_DIR="$PRESETS_DIR/$name"
done
[ -n "$PRESET_DIR" ] || die "$USAGE (presets: $PREFIX repoconfig --list)"
MISE_SRC="$PRESET_DIR/mise.toml"
EXT_SRC="$PRESET_DIR/extensions.json"
DEVCONTAINER_SRC="$PRESET_DIR/devcontainer.json"

[ -n "$EMAIL" ] || die "$USAGE"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "not inside a git repository"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || die "cannot enter $REPO_ROOT"

printf '\n\033[1;34m== %s (%s)\033[0m\n' "$(basename "$REPO_ROOT")" "$PRESET"

# The steps, local and instant first, the network last. lib/shell-script.nix
# inlines them here when the command is built.
# shellcheck source=repoconfig.d/setup.sh
. "$PARTS/setup.sh"

# shellcheck source=repoconfig.d/sandbox.sh
. "$PARTS/sandbox.sh"

# shellcheck source=repoconfig.d/resolve.sh
. "$PARTS/resolve.sh"
