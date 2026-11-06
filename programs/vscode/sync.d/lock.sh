# shellcheck shell=bash
# Part of sync.sh, inlined into it in order at build time.
# Detaches or takes the lock, and defines report_missing for the two
# sides below.

# Detached runs write to a log, never to the terminal. A background job
# printing to a shell that has already drawn its prompt leaves the cursor
# stranded below the output, so the shell looks hung until you press enter.
if [ -n "$DETACH" ]; then
  "$0" "$@" >"$LOG_FILE" 2>&1 &
  exit 0
fi

# One lock. The extension set is global, so two syncs for different projects
# would otherwise interleave install and uninstall calls against the same set
# and leave whichever finished last as the winner.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "[vscode] Another sync is already running, leaving it to finish."
  exit 0
fi

FAIL=0

# `code --install-extension` exits 0 even when it installs nothing, which it
# does for an ID that has been renamed or pulled from the marketplace. Left
# unchecked the sync reports success, writes the marker, and the fast path
# then suppresses every future attempt, so the plugin is missing forever and
# nothing ever says so. Re-read the installed set afterwards and complain.
report_missing() { # label  installed-list
  local label="$1" installed="$2"
  for ext in $DESIRED_EXTS; do
    if ! echo "$installed" | grep -qx "$ext"; then
      echo "[vscode] [$label] NOT INSTALLED: $ext"
      echo "[vscode] [$label]   try: code --install-extension $ext --force"
      FAIL=1
    fi
  done
}
