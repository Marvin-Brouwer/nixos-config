# shellcheck shell=bash
# `vscode-sync`. What it syncs, and why it works the way it does, is in
# default.nix.
#
# Built by default.nix with writeShellApplication: the tools it calls come from
# runtimeInputs on PATH, and the variables checked below are set by Nix ahead
# of this script.

: "${PREFIX:?}" "${EXTENSIONS_JSON_PY:?}"
# programs/vscode-plugins.nix, lowercased, one per line.
: "${BASE_EXTS?}"

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

MARKER_DIR="${HOME}/.config/nixos-vscode-sync"
LOCK_FILE="${MARKER_DIR}/sync.lock"
LOG_FILE="${MARKER_DIR}/last.log"
mkdir -p "$MARKER_DIR"

case "${1:-}" in
  -h|--help)
    cat <<HELP
usage: $PREFIX vscode-sync [--wait|--detach]

Makes the installed VSCode plugins (Windows and WSL side) equal the base list
in programs/vscode-plugins.nix plus this repo's .vscode/extensions.json.
Runs by itself on entering a repo with a mise.toml.

  (no option)  sync now, in the foreground
  --wait       wait for a sync the enter hook started
  --detach     sync in the background, logging to last.log
HELP
    exit 0 ;;
esac

# --detach backgrounds the sync and logs instead of printing. The hook does
# not use it: waiting and seeing the output is worth more than an instant
# `cd`, given the fast path already makes an unchanged entry free.
DETACH=""
if [ "${1:-}" = "--detach" ]; then
  DETACH=1
  shift
fi

# `vscode-sync --wait` blocks until a sync started by the hook has finished,
# so there is something to run before opening VSCode rather than guessing
# from scrollback.
if [ "${1:-}" = "--wait" ]; then
  if ! flock -n "$LOCK_FILE" true; then
    echo "[vscode] Waiting for the running sync to finish..."
  fi
  flock "$LOCK_FILE" true
  echo "[vscode] Sync idle."
  [ -s "$LOG_FILE" ] && echo "[vscode] Last detached run: $LOG_FILE"
  exit 0
fi

# Only act inside a repo this setup manages.
#
# The enter hook lives in the system mise config, so mise fires it on every
# directory change anywhere on the box, not just in projects. Without this
# guard, a `cd /mnt/c` rewrites the extension set to match a directory that
# is not a project at all, silently uninstalling whatever the last real
# project had installed.
#
# A mise.toml is what marks a repo as managed here; `repoconfig` writes one.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

REPO_ROOT="$(repo_root)"
if [ ! -f "$REPO_ROOT/mise.toml" ] && [ ! -f "$REPO_ROOT/.mise.toml" ]; then
  exit 0
fi

# A sandboxed repo is one I do not trust, so its .vscode/extensions.json does
# not get to install plugins on the host. Its plugins live in the container.
if [ "$(git -C "$REPO_ROOT" config --bool repoconfig.sandbox 2>/dev/null)" = true ]; then
  exit 0
fi

REPO_NAME="$(basename "$REPO_ROOT")"
EXT_FILE="$REPO_ROOT/.vscode/extensions.json"

# One marker, not one per repo. The installed set is global, so a per-repo
# marker would fast-path out on returning to a repo whose plugins another
# repo had since uninstalled.
MARKER_FILE="${MARKER_DIR}/installed.hash"

# --- Windows VSCode user settings ---
# The integrated terminal defaults to this distro, and Dev Containers stops
# forwarding host credentials into containers. A container opened by
# `rig repoconfig --sandbox` exists to keep a repo's dependencies away from
# those, and these are user settings on the Windows side, so they cannot be
# set from the container's own devcontainer.json. They apply to every dev
# container: push from the host, not from inside one. See docs/sandbox.md.
#
# Marker-guarded, so this is a file test on every run but the first. The
# marker name changes whenever the set of settings does, so an existing
# install picks up the additions once.
ensure_settings() {
  if [ -f "${MARKER_DIR}/settings-configured-v2" ]; then
    return 0
  fi
  if ! command -v cmd.exe >/dev/null 2>&1; then
    return 0
  fi

  WIN_APPDATA=$(cd /mnt/c && cmd.exe /c "echo %APPDATA%" 2>/dev/null | tr -d '\r')
  # C:\Users\... -> /mnt/c/Users/...
  WSL_APPDATA=$(echo "$WIN_APPDATA" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/mnt/\L\1|')
  SETTINGS_FILE="$WSL_APPDATA/Code/User/settings.json"

  if [ ! -f "$SETTINGS_FILE" ]; then
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo '{}' > "$SETTINGS_FILE"
  fi

  DISTRO="${WSL_DISTRO_NAME:-NixOS}"
  jq \
    --arg name "$DISTRO (WSL)" \
    --arg distro "$DISTRO" \
    '
      ."terminal.integrated.defaultProfile.windows" = $name |
      ."terminal.integrated.profiles.windows" += {
        ($name): {
          "path": "C:\\WINDOWS\\System32\\wsl.exe",
          "args": ["-d", $distro]
        }
      } |
      ."dev.containers.copyGitConfig" = false |
      ."dev.containers.gitCredentialHelperConfigLocation" = "none" |
      ."dev.containers.dockerCredentialHelper" = false |
      ."dev.containers.githubCLILoginWithToken" = false
    ' \
    "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" \
    && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

  touch "${MARKER_DIR}/settings-configured-v2"
  echo "[vscode] Set default terminal to '$DISTRO (WSL)', dev container credential forwarding off."
}

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

DESIRED_EXTS="$( { printf '%s\n' "$BASE_EXTS"; read_list recommendations; } | normalise )"
UNWANTED="$( read_list unwantedRecommendations | normalise )"

if [ -n "$UNWANTED" ]; then
  UNWANTED_FILE="$(mktemp)"
  printf '%s\n' "$UNWANTED" > "$UNWANTED_FILE"
  DESIRED_EXTS="$(printf '%s\n' "$DESIRED_EXTS" | grep -vxF -f "$UNWANTED_FILE" || true)"
  rm -f "$UNWANTED_FILE"
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

ensure_settings

# Fast path. Runs on every project entry, so it must stay cheap.
if [ -f "$MARKER_FILE" ] && [ "$(cat "$MARKER_FILE")" = "$DESIRED_HASH" ]; then
  exit 0
fi

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

# Only record the hash if everything landed, so a failure retries next time.
if [ "$FAIL" -eq 0 ]; then
  printf '%s\n' "$DESIRED_HASH" > "$MARKER_FILE"
  echo "[vscode] Extensions are up to date for $REPO_NAME."
else
  echo "[vscode] Some plugins did not install. Will retry next time."
fi
