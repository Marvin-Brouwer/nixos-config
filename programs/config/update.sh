# shellcheck shell=bash
# `config update`: switch the config checkout to main, fast-forward it to the remote
# and, when that changed what is checked out, build and switch to it. main, at
# the bottom, is the whole run in order; the steps are in update.d/.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${PREFIX:?}" "${REMOTE:?}" "${BRANCH:?}" "${BUILD:?}" "${SYSUPDATE_STATE_DIR:?}"

# Defines highlight.
# shellcheck source=../../lib/highlight.sh
. "$HIGHLIGHT"

# Defines repo_root.
# shellcheck source=../../lib/config-repo.sh
. "$CONFIG_REPO"

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$(highlight "$*")"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$(highlight "$*")"; }
die()  { printf '\033[1;31mconfig update:\033[0m %s\n' "$(highlight "$*")" >&2; exit 1; }
usage() {
  cat <<USAGE
usage: $PREFIX config update

Switches the checkout /etc/nixos points at to $BRANCH, fast-forwards it to
$REMOTE/$BRANCH and, when that changed what is checked out, runs
'$PREFIX config build' on it. Refuses to start with uncommitted changes, and
stops when $BRANCH and $REMOTE/$BRANCH have diverged. For another branch,
check it out and run '$PREFIX config build'. See docs/config.md.
USAGE
}

# The steps, inlined here by lib/shell-script.nix when the command is built.
# shellcheck source=update.d/checkout.sh
. "$PARTS/checkout.sh"
# shellcheck source=update.d/fetch.sh
. "$PARTS/fetch.sh"
# shellcheck source=update.d/notice.sh
. "$PARTS/notice.sh"

parse_args() {
  case "${1:-}" in
    "")        ;;
    -h|--help) usage; exit 0 ;;
    *)         usage >&2; die "unknown option: $1" ;;
  esac
}

main() {
  parse_args "$@"
  enter_checkout
  require_clean_tree

  fetch_main
  switch_to_main
  fast_forward_main
  stop_if_unchanged
  list_new_commits

  "$BUILD" || exit
  refresh_update_notice
}

main "$@"
