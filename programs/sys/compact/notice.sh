# shellcheck shell=bash
# `compact-notice`, printed on interactive shell start, but only when there is
# no sysupdate to run: sysupdate-notice has nothing pending or staged to show.
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.
#
# A file test and a cat, like sysupdate-notice. It stays quiet while sysupdate
# has something to say: one nag per shell, and the update comes first, since
# applying it only adds another generation to clean up afterwards.

set -u

: "${STATE_DIR:?}" "${SYSUPDATE_STATE_DIR:?}"

# --force is for `compact --status`, which is asked for explicitly.
if [ "${1:-}" != "--force" ]; then
  [ -t 1 ] || exit 0
  [ -f "$SYSUPDATE_STATE_DIR/status.txt" ] && exit 0
fi

[ -f "$STATE_DIR/status.txt" ] || exit 0

if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
  cat "$STATE_DIR/status.txt"
else
  cat "$STATE_DIR/status.ansi"
fi
