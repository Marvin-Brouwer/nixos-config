# shellcheck shell=bash
# `sysupdate-notice`, printed on interactive shell start. Not run as is:
# default.nix fills in the @-delimited placeholders.
#
# A file test and a cat. No eval, no network, nothing slow between you and
# the prompt -- which is the only reason it is acceptable on every shell.

set -u

STATE_DIR=@stateDir@

# --force is for `sysupdate --status`, which is asked for explicitly.
if [ "${1:-}" != "--force" ] && [ ! -t 1 ]; then
  exit 0
fi

[ -f "$STATE_DIR/status.txt" ] || exit 0

if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
  @coreutils@/bin/cat "$STATE_DIR/status.txt"
else
  @coreutils@/bin/cat "$STATE_DIR/status.ansi"
fi
