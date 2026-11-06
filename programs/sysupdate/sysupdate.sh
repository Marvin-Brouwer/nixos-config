# shellcheck shell=bash
# `sysupdate`, the interactive command: bump inputs, build, diff, apply or
# stage. main, at the bottom, is the whole run in order; the steps are in
# sysupdate.d/.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${STATE_DIR:?}" "${HOST_NAME:?}" "${PREFIX:?}"
: "${REBOOT_HINT:?}" "${DIFF_PY:?}"
# 1 in WSL, empty elsewhere. Only the kernel check depends on it.
: "${IS_WSL?}"

# Defines highlight.
# shellcheck source=../../lib/highlight.sh
. "$HIGHLIGHT"

# Defines repo_root.
# shellcheck source=../../lib/config-repo.sh
. "$CONFIG_REPO"

# Defines info, warn, die, candidate_lock and input_revs.
# shellcheck source=helpers.sh
. "$HELPERS"

say()   { printf '   %s\n' "$*"; }
usage() {
  cat <<USAGE
usage: $PREFIX sys update [option]

  (no option)  update the inputs, build, show the diff, apply or stage
  --status     reprint the cached notice
  --check      run the background check now
  --audit      scan the running system for known vulnerabilities
USAGE
}

# The steps, inlined here by lib/shell-script.nix when the command is built.
# shellcheck source=sysupdate.d/select.sh
. "$PARTS/select.sh"
# shellcheck source=sysupdate.d/build.sh
. "$PARTS/build.sh"
# shellcheck source=sysupdate.d/commit.sh
. "$PARTS/commit.sh"
# shellcheck source=sysupdate.d/apply.sh
. "$PARTS/apply.sh"

# The options other than the default run. Each one ends the run.
run_option() {
  case "$1" in
    --status) exec sysupdate-notice --force ;;
    --audit)  exec vulnix --system ;;
    --check)
      info "Checking (this evaluates the whole configuration, give it a few minutes)..."
      rm -f "$STATE_DIR/last-attempt"
      sudo systemctl start sysupdate-check.service \
        || die "the check failed, see: \`journalctl -u sysupdate-check\`"
      echo
      sysupdate-notice --force || true
      exit 0
      ;;
    -h|--help) usage; exit 0 ;;
    *)         usage >&2; die "unknown option: $1" ;;
  esac
}

# Everything after this writes flake.lock and restores it on the way out, so
# it must start from a clean one or a discard would throw away your work.
enter_repo() {
  REPO=$(repo_root) || die "/etc/nixos does not resolve to a git repository"
  cd "$REPO" || die "cannot enter $REPO"

  git diff --quiet -- flake.lock \
    || die "flake.lock has uncommitted changes, commit or restore it first"
  git diff --cached --quiet -- flake.lock \
    || die "flake.lock is staged, commit or restore it first"

  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
}

main() {
  [ -z "${1:-}" ] || run_option "$1"
  enter_repo
  printf '\n\033[1;34m== sysupdate (%s)\033[0m\n\n' "$HOST_NAME"

  find_moved_inputs
  list_moved_inputs
  choose_inputs

  update_chosen_inputs
  build_system
  show_diff_and_ask

  case "$ACTION" in
    a|A)   apply_now ;;
    s|S)   stage_for_next_start ;;
    d|D|*) discard ;;
  esac
}

main "$@"
