# shellcheck shell=bash
# `sysupdate`, the interactive command: bump inputs, build, diff, apply or
# stage. Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

set -uo pipefail

: "${STATE_DIR:?}" "${HOST_NAME:?}" "${PREFIX:?}"
: "${REBOOT_HINT:?}" "${DIFF_PY:?}"
# 1 in WSL, empty elsewhere. Only the kernel check below depends on it.
: "${IS_WSL?}"

# Defines info, warn, die, repo_root, candidate_lock and input_revs.
# shellcheck source=helpers.sh
. "$HELPERS"

say()   { printf '   %s\n' "$*"; }
usage() {
  cat <<USAGE
usage: $PREFIX sysupdate [option]

  (no option)  update the inputs, build, show the diff, apply or stage
  --status     reprint the cached notice
  --check      run the background check now
  --audit      scan the running system for known vulnerabilities
USAGE
}

case "${1:-}" in
  --status) exec sysupdate-notice --force ;;
  --audit)  exec vulnix --system ;;
  --check)
    info "Checking (this evaluates the whole configuration, give it a few minutes)..."
    rm -f "$STATE_DIR/last-attempt"
    sudo systemctl start sysupdate-check.service \
      || die "the check failed, see: journalctl -u sysupdate-check"
    echo
    sysupdate-notice --force || true
    exit 0
    ;;
  -h|--help) usage; exit 0 ;;
  "")        ;;
  *)         usage >&2; die "unknown option: $1" ;;
esac

REPO=$(repo_root) || die "/etc/nixos does not resolve to a git repository"
cd "$REPO" || die "cannot enter $REPO"

# Everything below writes flake.lock and restores it on the way out, so it
# must start from a clean one or a discard would throw away your work.
git diff --quiet -- flake.lock \
  || die "flake.lock has uncommitted changes, commit or restore it first"
git diff --cached --quiet -- flake.lock \
  || die "flake.lock is staged, commit or restore it first"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf '\n\033[1;34m== sysupdate (%s)\033[0m\n\n' "$HOST_NAME"

# The steps, inlined here by lib/shell-script.nix when the command is built.
# Each part carries on where the previous one stopped.
# shellcheck source=sysupdate.d/select.sh
. "$PARTS/select.sh"

# shellcheck source=sysupdate.d/build.sh
. "$PARTS/build.sh"

# shellcheck source=sysupdate.d/commit.sh
. "$PARTS/commit.sh"

# shellcheck source=sysupdate.d/apply.sh
. "$PARTS/apply.sh"
