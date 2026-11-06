# shellcheck shell=bash
# Part of sync.sh, inlined into it at build time.
# Running in the background, or holding the one lock in the foreground.

# Detached runs write to a log, never to the terminal. A background job
# printing to a shell that has already drawn its prompt leaves the cursor
# stranded below the output, so the shell looks hung until you press enter.
# Reruns this script, without --detach, with the arguments it is given.
detach() {
  "$0" "$@" >"$LOG_FILE" 2>&1 &
  exit 0
}

# One lock. The extension set is global, so two syncs for different projects
# would otherwise interleave install and uninstall calls against the same set
# and leave whichever finished last as the winner. Held until the script
# exits, since exec opens it on the script's own fd 9.
take_lock() {
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    echo "[vscode] Another sync is already running, leaving it to finish."
    exit 0
  fi
}

# `vscode-sync --wait` blocks until a sync started by the hook has finished,
# so there is something to run before opening VSCode rather than guessing
# from scrollback.
wait_for_sync() {
  if ! flock -n "$LOCK_FILE" true; then
    echo "[vscode] Waiting for the running sync to finish..."
  fi
  flock "$LOCK_FILE" true
  echo "[vscode] Sync idle."
  [ -s "$LOG_FILE" ] && echo "[vscode] Last detached run: $LOG_FILE"
}
