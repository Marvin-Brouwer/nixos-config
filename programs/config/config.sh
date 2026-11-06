# shellcheck shell=bash
# `config`: hands `build` and `update` to their own scripts, which do the work.
#
# Built by default.nix with writeShellApplication; the variables checked below
# are set by Nix ahead of this script.

set -uo pipefail

: "${PREFIX:?}" "${BUILD:?}" "${UPDATE:?}"

usage() {
  cat <<USAGE
usage: $PREFIX config <build|update> [args...]

  build   build the checked-out branch of this config and switch to it
  update  back to main: pull it, and build when that changed anything

'$PREFIX config <subcommand> --help' for details. See docs/config.md.
USAGE
}

main() {
  local sub=${1:-}
  [ $# -gt 0 ] && shift
  case "$sub" in
    build)        exec "$BUILD" "$@" ;;
    update)       exec "$UPDATE" "$@" ;;
    ""|-h|--help) usage ;;
    *)
      usage >&2
      printf '\033[1;31mconfig:\033[0m unknown subcommand: %s\n' "$sub" >&2
      exit 1
      ;;
  esac
}

main "$@"
