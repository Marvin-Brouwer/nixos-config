# shellcheck shell=bash
# `sysupdate-notice`, printed on interactive shell start. 
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.
#
# A file test and a cat. No eval, no network, nothing slow between you and
# the prompt -- which is the only reason it is acceptable on every shell.

set -u

: "${STATE_DIR:?}"

# --force is for `sysupdate --status`, which is asked for explicitly.
if [ "${1:-}" != "--force" ] && [ ! -t 1 ]; then
  exit 0
fi

[ -f "$STATE_DIR/status.txt" ] || exit 0

if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
  cat "$STATE_DIR/status.txt"
else
  cat "$STATE_DIR/status.ansi"
fi
