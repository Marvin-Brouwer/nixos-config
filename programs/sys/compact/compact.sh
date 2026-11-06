# shellcheck shell=bash
# `compact`, the interactive command: show what would go, ask, then prune the
# Nix store, Docker and mise, trim the disk, and say how much came back.
# main, at the bottom, is the whole run in order; the steps are in compact.d/.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${STATE_DIR:?}" "${KEEP_DAYS:?}" "${PREFIX:?}"
# 1 in WSL, empty elsewhere. Only the trim and the disk hint depend on it.
: "${IS_WSL?}"

# Defines highlight.
# shellcheck source=../../../lib/highlight.sh
. "$HIGHLIGHT"

# Defines info, warn, die, dead_bytes, old_generations and human.
# shellcheck source=helpers.sh
. "$HELPERS"

say() { printf '   %s\n' "$*"; }
usage() {
  cat <<USAGE
usage: $PREFIX sys compact [option]

  (no option)  show what would be removed, ask, then remove it
  --yes, -y    the same without asking
  --status     reprint the cached notice
  --check      measure now and print the notice, removing nothing

Keeps the last $KEEP_DAYS days of system generations. See docs/compact.md.
USAGE
}

# The steps, inlined here by lib/shell-script.nix when the command is built.
# shellcheck source=compact.d/plan.sh
. "$PARTS/plan.sh"
# shellcheck source=compact.d/prune.sh
. "$PARTS/prune.sh"
# shellcheck source=compact.d/disk.sh
. "$PARTS/disk.sh"

# Sets ASSUME_YES, or runs one of the options that end the run.
parse_args() {
  ASSUME_YES=""
  case "${1:-}" in
    "")       ;;
    -y|--yes) ASSUME_YES=1 ;;
    --status) exec compact-notice --force ;;
    --check)
      info "Measuring (this walks the Nix store, give it a moment)..."
      compact-check --force >/dev/null || die "the check failed"
      compact-notice --force || true
      [ -f "$STATE_DIR/status.txt" ] || info "Nothing worth cleaning up."
      exit 0
      ;;
    -h|--help) usage; exit 0 ;;
    *)         usage >&2; die "unknown option: $1" ;;
  esac
}

main() {
  parse_args "$@"
  printf '\n\033[1;34m== compact\033[0m\n\n'

  USED_BEFORE=$(used_bytes)
  show_plan
  confirm

  delete_old_generations
  prune_docker
  prune_mise
  trim_disk

  report_freed
  # The next check would say the same thing; no point nagging until then.
  rm -f "$STATE_DIR/status.txt" "$STATE_DIR/status.ansi"
  vhd_hint
}

main "$@"
