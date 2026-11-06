# shellcheck shell=bash
# Part of sync.sh, inlined into it in order at build time.
# Records the set as installed, if every plugin landed.

# Only record the hash if everything landed, so a failure retries next time.
if [ "$FAIL" -eq 0 ]; then
  printf '%s\n' "$DESIRED_HASH" > "$MARKER_FILE"
  echo "[vscode] Extensions are up to date for $REPO_NAME."
else
  echo "[vscode] Some plugins did not install. Will retry next time."
fi
