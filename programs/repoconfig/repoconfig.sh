# shellcheck shell=bash
# The `repoconfig` command. main, at the bottom, is the whole run in order;
# the steps are in repoconfig.d/.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${PREFIX:?}" "${USAGE:?}" "${GIT_USER_NAME:?}" "${LIST_FILE:?}"
: "${PRESETS_DIR:?}" "${PRESET_NAMES:?}" "${SANDBOX_CHECK:?}"

EXCLUDE=".git/info/exclude"

# Defines highlight.
# shellcheck source=../../lib/highlight.sh
. "$HIGHLIGHT"

say()  { printf '   %s\n' "$(highlight "$*")"; }
made() { printf '   \033[1;32mcreated\033[0m %s\n' "$*"; }
kept() { printf '   \033[1;33mkept\033[0m    %s (already present)\n' "$*"; }
die()  { printf '\033[1;31mrepoconfig:\033[0m %s\n' "$(highlight "$*")" >&2; exit 1; }

# The steps, inlined here by lib/shell-script.nix when the command is built.
# shellcheck source=repoconfig.d/help.sh
. "$PARTS/help.sh"
# shellcheck source=repoconfig.d/setup.sh
. "$PARTS/setup.sh"
# shellcheck source=repoconfig.d/sandbox.sh
. "$PARTS/sandbox.sh"
# shellcheck source=repoconfig.d/resolve.sh
. "$PARTS/resolve.sh"

# Sets SANDBOX, PRESET and EMAIL. --sandbox may go anywhere; the rest is
# positional.
parse_args() {
  local arg args=()
  SANDBOX=
  for arg in "$@"; do
    case "$arg" in
      --sandbox) SANDBOX=1 ;;
      *) args+=("$arg") ;;
    esac
  done
  PRESET="${args[0]:-}"
  EMAIL="${args[1]:-}"
}

# Sets PRESET_DIR and the sources in it. One directory per preset, built by
# default.nix: mise.toml, extensions.json, devcontainer.json, and files/ for
# anything else the preset writes. Looked up by name rather than by path, so
# an argument like ../ cannot point it anywhere.
find_preset() {
  local name presets
  read -ra presets <<< "$PRESET_NAMES"
  PRESET_DIR=
  for name in "${presets[@]}"; do
    [ "$name" = "$PRESET" ] && PRESET_DIR="$PRESETS_DIR/$name"
  done
  [ -n "$PRESET_DIR" ] || die "$USAGE (presets: \`$PREFIX repo init --list\`)"
  MISE_SRC="$PRESET_DIR/mise.toml"
  EXT_SRC="$PRESET_DIR/extensions.json"
  DEVCONTAINER_SRC="$PRESET_DIR/devcontainer.json"
}

enter_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git repository"
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  cd "$REPO_ROOT" || die "cannot enter $REPO_ROOT"
  printf '\n\033[1;34m== %s (%s)\033[0m\n' "$(basename "$REPO_ROOT")" "$PRESET"
}

main() {
  parse_args "$@"
  case "$PRESET" in
    -h|--help) print_help; exit 0 ;;
    -l|--list) cat "$LIST_FILE"; exit 0 ;;
  esac
  find_preset
  [ -n "$EMAIL" ] || die "$USAGE"
  enter_repo

  # Local and instant first, the network last.
  set_git_identity
  write_mise_toml
  trust_mise
  create_mise_lock
  write_extensions_json
  install_preset_files
  exclude_local_files

  # The sandbox stops here: every step below runs the repo's config on the
  # host, which is exactly what it is for avoiding.
  if [ -n "$SANDBOX" ]; then
    write_sandbox
    echo
    say "Done. Open the repo in VS Code and run \`Dev Containers: Reopen in Container\`."
    echo
    exit 0
  fi

  resolve_and_lock
  sync_plugins
  printf '\n   Done.\n\n'
}

main "$@"
