# shellcheck shell=bash
# `config build`: build the system from a checkout of this repo, show what
# changes and switch to it. main, at the bottom, is the whole run in order;
# the steps are in build.d/.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${HOST_NAME:?}" "${PREFIX:?}"

# Defines highlight.
# shellcheck source=../../../lib/highlight.sh
. "$HIGHLIGHT"

# Defines repo_root.
# shellcheck source=../../../lib/config-repo.sh
. "$CONFIG_REPO"

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$(highlight "$*")"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$(highlight "$*")"; }
die()  { printf '\033[1;31mconfig build:\033[0m %s\n' "$(highlight "$*")" >&2; exit 1; }
usage() {
  cat <<USAGE
usage: $PREFIX config build

Builds the system from the checkout /etc/nixos points at, shows what changes
and switches to it: 'sudo nixos-rebuild switch --flake <checkout>#$HOST_NAME',
on whatever branch is checked out, uncommitted changes included.
See docs/config.md.
USAGE
}

# The steps, inlined here by lib/shell-script.nix when the command is built.
# shellcheck source=build.d/target.sh
. "$PARTS/target.sh"
# shellcheck source=build.d/system.sh
. "$PARTS/system.sh"

parse_args() {
  case "${1:-}" in
    "")        ;;
    -h|--help) usage; exit 0 ;;
    *)         usage >&2; die "unknown option: $1" ;;
  esac
}

main() {
  parse_args "$@"
  find_checkout
  printf '\n\033[1;34m== config build (%s)\033[0m\n\n' "$HOST_NAME"

  describe_checkout
  warn_on_untracked_files

  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  build_system
  stop_if_already_running
  show_diff
  switch_system
}

main "$@"
