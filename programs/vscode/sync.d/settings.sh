# shellcheck shell=bash
# Part of sync.sh, inlined into it at build time.
# The one-off Windows VSCode user settings.

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
