# shellcheck shell=bash
# Part of sync.sh, inlined into it at build time.
# Making each side's installed set equal DESIRED_EXTS. Sets FAIL=1 when a
# plugin did not land.

# `code --install-extension` exits 0 even when it installs nothing, which it
# does for an ID that has been renamed or pulled from the marketplace. Left
# unchecked the sync reports success, writes the marker, and the fast path
# then suppresses every future attempt, so the plugin is missing forever and
# nothing ever says so. Re-read the installed set afterwards and complain.
report_missing() { # label  installed-list
  local label="$1" installed="$2" ext
  for ext in $DESIRED_EXTS; do
    if ! echo "$installed" | grep -qx "$ext"; then
      echo "[vscode] [$label] NOT INSTALLED: $ext"
      echo "[vscode] [$label]   try: code --install-extension $ext --force"
      FAIL=1
    fi
  done
}

# cmd.exe cannot use a UNC path as its working directory, hence the cd.
win_code() {
  (cd /mnt/c && cmd.exe /c code "$@") | tr -d '\r'
}

sync_windows() {
  local installed ext
  echo "[vscode] Syncing Windows extensions for $REPO_NAME..."
  installed=$(win_code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

  for ext in $DESIRED_EXTS; do
    if ! echo "$installed" | grep -qx "$ext"; then
      echo "[vscode] [win] Installing $ext..."
      if ! win_code --install-extension "$ext" --force >/dev/null 2>&1; then
        echo "[vscode] [win] WARNING: Failed to install $ext"
        FAIL=1
      fi
    fi
  done

  for ext in $installed; do
    if ! echo "$DESIRED_EXTS" | grep -qx "$ext"; then
      echo "[vscode] [win] Removing $ext..."
      win_code --uninstall-extension "$ext" >/dev/null 2>&1
    fi
  done

  report_missing win "$(win_code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
}

# Installs into the VS Code remote server.
sync_wsl() {
  local installed ext
  echo "[vscode] Syncing WSL extensions for $REPO_NAME..."
  installed=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

  for ext in $DESIRED_EXTS; do
    if ! echo "$installed" | grep -qx "$ext"; then
      echo "[vscode] [wsl] Installing $ext..."
      if ! code --install-extension "$ext" --force >/dev/null 2>&1; then
        echo "[vscode] [wsl] WARNING: Failed to install $ext"
        FAIL=1
      fi
    fi
  done

  for ext in $installed; do
    if ! echo "$DESIRED_EXTS" | grep -qx "$ext"; then
      echo "[vscode] [wsl] Removing $ext..."
      code --uninstall-extension "$ext" >/dev/null 2>&1
    fi
  done

  report_missing wsl "$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
}

# Only record the hash if everything landed, so a failure retries next time.
record_result() {
  if [ "$FAIL" -eq 0 ]; then
    printf '%s\n' "$DESIRED_HASH" > "$MARKER_FILE"
    echo "[vscode] Extensions are up to date for $REPO_NAME."
  else
    echo "[vscode] Some plugins did not install. Will retry next time."
  fi
}
