# shellcheck shell=bash
# Part of sync.sh, inlined into it at build time.
# The plugin set this repo wants, and whether it is already installed.

# Pull one array out of the project's extensions.json, if it has one.
read_list() {
  [ -f "$EXT_FILE" ] || return 0
  python3 "$EXTENSIONS_JSON_PY" "$EXT_FILE" "$1"
}

normalise() {
  tr '[:upper:]' '[:lower:]' \
    | grep -v '^[[:space:]]*$' \
    | sort -u
}

# Sets DESIRED_EXTS and DESIRED_HASH: the base list plus the project's
# recommendations, minus its unwanted ones.
want_plugins() {
  local unwanted unwanted_file
  DESIRED_EXTS="$( { printf '%s\n' "$BASE_EXTS"; read_list recommendations; } | normalise )"
  unwanted="$( read_list unwantedRecommendations | normalise )"

  if [ -n "$unwanted" ]; then
    unwanted_file="$(mktemp)"
    printf '%s\n' "$unwanted" > "$unwanted_file"
    DESIRED_EXTS="$(printf '%s\n' "$DESIRED_EXTS" | grep -vxF -f "$unwanted_file" || true)"
    rm -f "$unwanted_file"
  fi

  # The WSL remote extension is machine-specific infrastructure rather than a
  # preference, so it is not in the base list. Without it VSCode cannot open a
  # WSL folder at all, it just reports "Disconnected from vscode-remote". On a
  # box with no WSL remote there is nothing for it to connect to.
  #
  # Added after the unwanted filter on purpose: vetoing the extension that
  # makes the editor reach this machine is never what a project meant.
  #
  # Dev Containers rides along for the same reason: `rig repoconfig --sandbox`
  # depends on it, and the sync would otherwise uninstall it as unlisted.
  if command -v cmd.exe >/dev/null 2>&1; then
    DESIRED_EXTS="$(printf '%s\nms-vscode-remote.remote-wsl\nms-vscode-remote.remote-containers\n' "$DESIRED_EXTS" | normalise)"
  fi

  DESIRED_HASH=$(printf '%s\n' "$DESIRED_EXTS" | sha256sum | cut -d' ' -f1)
}

# Fast path. Runs on every project entry, so it must stay cheap.
skip_if_installed() {
  if [ -f "$MARKER_FILE" ] && [ "$(cat "$MARKER_FILE")" = "$DESIRED_HASH" ]; then
    exit 0
  fi
}
