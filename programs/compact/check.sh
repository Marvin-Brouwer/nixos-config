# shellcheck shell=bash
# `compact-check`, the background job behind the notice, run by a systemd
# timer. main, at the bottom, is the whole run in order.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.
#
# Only measures. Listing dead store paths walks the store, which is fine at
# idle priority in a timer and not fine in front of a prompt.

set -uo pipefail

: "${STATE_DIR:?}" "${KEEP_DAYS:?}" "${PREFIX:?}"
: "${DEAD_THRESHOLD:?}" "${GENERATIONS_THRESHOLD:?}" "${MIN_INTERVAL:?}"

# Defines highlight.
# shellcheck source=../../lib/highlight.sh
. "$HIGHLIGHT"

# Defines info, warn, die, dead_bytes, old_generations and human.
# shellcheck source=helpers.sh
. "$HELPERS"

# A file rather than timer state, for the same reason as sysupdate-check: timer
# state does not survive a WSL shutdown.
skip_if_checked_recently() {
  local now last
  [ -z "$FORCE" ] && [ -f "$STAMP" ] || return 0
  now=$(date +%s)
  last=$(stat -c %Y "$STAMP")
  if [ "$((now - last))" -lt "$MIN_INTERVAL" ]; then
    echo "[compact] checked $(( (now - last) / 3600 ))h ago, nothing to do"
    exit 0
  fi
}

measure() {
  DEAD=$(dead_bytes)
  GENERATIONS=$(old_generations)
}

worth_it() {
  [ "$DEAD" -ge "$DEAD_THRESHOLD" ] || [ "$GENERATIONS" -ge "$GENERATIONS_THRESHOLD" ]
}

# Written to a temp file and moved, so a shell starting mid-write never prints
# half a notice.
write_notice() {
  local reasons=()
  [ "$DEAD" -gt 0 ] && reasons+=("$(human "$DEAD") of unused store paths")
  [ "$GENERATIONS" -gt 0 ] \
    && reasons+=("$GENERATIONS system generations older than $KEEP_DAYS days")

  {
    echo "This machine could use a clean-up:"
    printf ' - %s\n' "${reasons[@]}"
    echo
    echo " run \`$PREFIX sys compact --yes\` to reclaim it"
  } > "$STATE_DIR/status.txt.tmp"

  {
    printf '\033[1;33mThis machine could use a clean-up:\033[0m\n'
    printf ' - %s\n' "${reasons[@]}"
    printf '\n %s\n' "$(highlight "run \`$PREFIX sys compact --yes\` to reclaim it")"
  } > "$STATE_DIR/status.ansi.tmp"

  mv "$STATE_DIR/status.txt.tmp" "$STATE_DIR/status.txt"
  mv "$STATE_DIR/status.ansi.tmp" "$STATE_DIR/status.ansi"
}

clear_notice() {
  rm -f "$STATE_DIR/status.txt" "$STATE_DIR/status.ansi"
}

main() {
  FORCE=""
  [ "${1:-}" = "--force" ] && FORCE=1

  mkdir -p "$STATE_DIR"
  STAMP="$STATE_DIR/last-check"

  skip_if_checked_recently
  touch "$STAMP"

  measure
  if worth_it; then
    write_notice
    echo "[compact] $(human "$DEAD") dead, $GENERATIONS old generations: notice written"
  else
    clear_notice
    echo "[compact] $(human "$DEAD") dead, $GENERATIONS old generations: nothing to say"
  fi
}

main "$@"
