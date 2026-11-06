# shellcheck shell=bash
# Part of sync.sh, inlined into it in order at build time.
# Syncs the VSCode server in WSL.

# --- WSL side: install into the VS Code remote server ---
if command -v code >/dev/null 2>&1; then
  echo "[vscode] Syncing WSL extensions for $REPO_NAME..."
  WSL_INSTALLED=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

  for ext in $DESIRED_EXTS; do
    if ! echo "$WSL_INSTALLED" | grep -qx "$ext"; then
      echo "[vscode] [wsl] Installing $ext..."
      if ! code --install-extension "$ext" --force >/dev/null 2>&1; then
        echo "[vscode] [wsl] WARNING: Failed to install $ext"
        FAIL=1
      fi
    fi
  done

  for ext in $WSL_INSTALLED; do
    if ! echo "$DESIRED_EXTS" | grep -qx "$ext"; then
      echo "[vscode] [wsl] Removing $ext..."
      code --uninstall-extension "$ext" >/dev/null 2>&1
    fi
  done

  report_missing wsl "$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
fi
