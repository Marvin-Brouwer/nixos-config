# shellcheck shell=bash
# Part of sync.sh, inlined into it in order at build time.
# Syncs the Windows VSCode.

# --- Windows side ---
# cmd.exe cannot use a UNC path as its working directory, hence the cd.
if command -v cmd.exe >/dev/null 2>&1; then
  win_code() {
    (cd /mnt/c && cmd.exe /c code "$@") | tr -d '\r'
  }

  echo "[vscode] Syncing Windows extensions for $REPO_NAME..."
  WIN_INSTALLED=$(win_code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

  for ext in $DESIRED_EXTS; do
    if ! echo "$WIN_INSTALLED" | grep -qx "$ext"; then
      echo "[vscode] [win] Installing $ext..."
      if ! win_code --install-extension "$ext" --force >/dev/null 2>&1; then
        echo "[vscode] [win] WARNING: Failed to install $ext"
        FAIL=1
      fi
    fi
  done

  for ext in $WIN_INSTALLED; do
    if ! echo "$DESIRED_EXTS" | grep -qx "$ext"; then
      echo "[vscode] [win] Removing $ext..."
      win_code --uninstall-extension "$ext" >/dev/null 2>&1
    fi
  done

  report_missing win "$(win_code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
fi
