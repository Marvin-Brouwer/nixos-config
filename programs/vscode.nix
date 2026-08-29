# -----------------------------------------------------------------
# VSCode plugin sync, triggered by the mise `enter` hook in programs/mise.toml.
#
# What it installs is the union of two lists:
#
#   * programs/vscode-plugins.nix -- mine, wanted everywhere.
#   * <repo>/.vscode/extensions.json -- the project's, and the standard
#     file VSCode already prompts contributors to install. Nothing here is
#     mise-specific or NixOS-specific, so a contributor gets the same set
#     through their own editor without knowing this exists.
#
# minus that file's `unwantedRecommendations`.
#
# The VSCode profile is named after the repo directory, because the plugin set
# is per-repo.
# -----------------------------------------------------------------

{ pkgs, lib }:

let
  basePlugins = import ./vscode-plugins.nix;

  # .vscode/extensions.json is JSONC: comments and trailing commas are
  # legal and worth keeping, which rules out jq.
  python = pkgs.python3.withPackages (ps: [ ps.json5 ]);

  # Both commands below have to agree on the profile name.
  profileName = ''
    repo_root() {
      ${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd
    }
    profile_name() {
      ${pkgs.coreutils}/bin/basename "$(repo_root)"
    }
  '';

  sync = pkgs.writeShellScriptBin "vscode-sync" ''
    ${profileName}

    # Only act inside a repo this setup manages.
    #
    # The enter hook lives in the system mise config, so mise fires it on every
    # directory change anywhere on the box, not just in projects. Without this
    # guard, a `cd /mnt/c` syncs a VSCode profile called "c" and rewrites the
    # shared WSL extension set to match a directory that is not a project at
    # all, silently uninstalling whatever the last real project had installed.
    #
    # A mise.toml is what marks a repo as managed here; `repoconfig` writes one.
    if ! ${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      exit 0
    fi

    REPO_ROOT="$(repo_root)"
    if [ ! -f "$REPO_ROOT/mise.toml" ] && [ ! -f "$REPO_ROOT/.mise.toml" ]; then
      exit 0
    fi

    PROFILE="$(profile_name)"
    EXT_FILE="$REPO_ROOT/.vscode/extensions.json"

    MARKER_DIR="''${HOME}/.config/nixos-vscode-profiles"
    MARKER_FILE="''${MARKER_DIR}/''${PROFILE}.hash"
    ${pkgs.coreutils}/bin/mkdir -p "$MARKER_DIR"

    # --- Windows VSCode: default the integrated terminal to this distro ---
    # Marker-guarded, so this is a file test on every run but the first.
    ensure_terminal() {
      if [ -f "''${MARKER_DIR}/terminal-configured" ]; then
        return 0
      fi
      if ! command -v cmd.exe >/dev/null 2>&1; then
        return 0
      fi

      WIN_APPDATA=$(cd /mnt/c && cmd.exe /c "echo %APPDATA%" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d '\r')
      # C:\Users\... -> /mnt/c/Users/...
      WSL_APPDATA=$(echo "$WIN_APPDATA" | ${pkgs.gnused}/bin/sed 's|\\|/|g; s|^\([A-Za-z]\):|/mnt/\L\1|')
      SETTINGS_FILE="$WSL_APPDATA/Code/User/settings.json"

      if [ ! -f "$SETTINGS_FILE" ]; then
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$SETTINGS_FILE")"
        echo '{}' > "$SETTINGS_FILE"
      fi

      DISTRO="''${WSL_DISTRO_NAME:-NixOS}"
      ${pkgs.jq}/bin/jq \
        --arg name "$DISTRO (WSL)" \
        --arg distro "$DISTRO" \
        '
          ."terminal.integrated.defaultProfile.windows" = $name |
          ."terminal.integrated.profiles.windows" += {
            ($name): {
              "path": "C:\\WINDOWS\\System32\\wsl.exe",
              "args": ["-d", $distro]
            }
          }
        ' \
        "$SETTINGS_FILE" > "''${SETTINGS_FILE}.tmp" \
        && ${pkgs.coreutils}/bin/mv "''${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

      ${pkgs.coreutils}/bin/touch "''${MARKER_DIR}/terminal-configured"
      echo "[vscode] Set default terminal to '$DISTRO (WSL)'."
    }

    # Pull one array out of the project's extensions.json, if it has one.
    read_list() {
      [ -f "$EXT_FILE" ] || return 0
      ${python}/bin/python3 ${./vscode-extensions-json.py} "$EXT_FILE" "$1"
    }

    normalise() {
      ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]' \
        | ${pkgs.gnugrep}/bin/grep -v '^[[:space:]]*$' \
        | ${pkgs.coreutils}/bin/sort -u
    }

    BASE_EXTS="${lib.concatStringsSep "\n" (map lib.toLower basePlugins)}"

    DESIRED_EXTS="$( { printf '%s\n' "$BASE_EXTS"; read_list recommendations; } | normalise )"
    UNWANTED="$( read_list unwantedRecommendations | normalise )"

    if [ -n "$UNWANTED" ]; then
      UNWANTED_FILE="$(${pkgs.coreutils}/bin/mktemp)"
      printf '%s\n' "$UNWANTED" > "$UNWANTED_FILE"
      DESIRED_EXTS="$(printf '%s\n' "$DESIRED_EXTS" | ${pkgs.gnugrep}/bin/grep -vxF -f "$UNWANTED_FILE" || true)"
      ${pkgs.coreutils}/bin/rm -f "$UNWANTED_FILE"
    fi

    DESIRED_HASH=$(printf '%s\n' "$DESIRED_EXTS" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)

    ensure_terminal

    # Fast path. Runs on every project entry, so it must stay cheap.
    if [ -f "$MARKER_FILE" ] && [ "$(${pkgs.coreutils}/bin/cat "$MARKER_FILE")" = "$DESIRED_HASH" ]; then
      exit 0
    fi

    # Slow path talks to the marketplace. Get off the shell's critical path
    # so entering a directory never blocks on the network.
    if [ -z "''${VSCODE_SYNC_FOREGROUND:-}" ]; then
      VSCODE_SYNC_FOREGROUND=1 "$0" "$@" &
      exit 0
    fi

    FAIL=0

    # --- Windows side: install into the named VS Code profile ---
    # cmd.exe cannot use a UNC path as its working directory, hence the cd.
    # The WSL `code` wrapper does not support --profile, the Windows CLI does.
    if command -v cmd.exe >/dev/null 2>&1; then
      win_code() {
        (cd /mnt/c && cmd.exe /c code --profile "$PROFILE" "$@") | ${pkgs.coreutils}/bin/tr -d '\r'
      }

      win_code --list-extensions >/dev/null 2>&1   # ensure the profile exists

      echo "[vscode] Syncing Windows profile '$PROFILE'..."
      WIN_INSTALLED=$(win_code --list-extensions 2>/dev/null | ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]')

      for ext in $DESIRED_EXTS; do
        if ! echo "$WIN_INSTALLED" | ${pkgs.gnugrep}/bin/grep -qx "$ext"; then
          echo "[vscode] [win] Installing $ext..."
          if ! win_code --install-extension "$ext" --force >/dev/null 2>&1; then
            echo "[vscode] [win] WARNING: Failed to install $ext"
            FAIL=1
          fi
        fi
      done

      for ext in $WIN_INSTALLED; do
        if ! echo "$DESIRED_EXTS" | ${pkgs.gnugrep}/bin/grep -qx "$ext"; then
          echo "[vscode] [win] Removing $ext..."
          win_code --uninstall-extension "$ext" >/dev/null 2>&1
        fi
      done
    fi

    # --- WSL side: install into the VS Code remote server ---
    if command -v code >/dev/null 2>&1; then
      echo "[vscode] Syncing WSL remote extensions..."
      WSL_INSTALLED=$(code --list-extensions 2>/dev/null | ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]')

      for ext in $DESIRED_EXTS; do
        if ! echo "$WSL_INSTALLED" | ${pkgs.gnugrep}/bin/grep -qx "$ext"; then
          echo "[vscode] [wsl] Installing $ext..."
          if ! code --install-extension "$ext" --force >/dev/null 2>&1; then
            echo "[vscode] [wsl] WARNING: Failed to install $ext"
            FAIL=1
          fi
        fi
      done

      for ext in $WSL_INSTALLED; do
        if ! echo "$DESIRED_EXTS" | ${pkgs.gnugrep}/bin/grep -qx "$ext"; then
          echo "[vscode] [wsl] Removing $ext..."
          code --uninstall-extension "$ext" >/dev/null 2>&1
        fi
      done
    fi

    # Only record the hash if everything landed, so a failure retries next time.
    if [ "$FAIL" -eq 0 ]; then
      printf '%s\n' "$DESIRED_HASH" > "$MARKER_FILE"
      echo "[vscode] Profile '$PROFILE' is up to date."
    else
      echo "[vscode] Some plugins failed to install. Will retry next time."
    fi
  '';

  # Opens VSCode with this repo's profile. Has to be a real script rather
  # than a shell function so it survives being on PATH.
  wrapper = pkgs.writeShellScriptBin "vscode" ''
    ${profileName}
    PROFILE="$(profile_name)"
    if [ $# -eq 0 ]; then
      exec code --profile "$PROFILE" .
    else
      exec code --profile "$PROFILE" "$@"
    fi
  '';

in
{
  inherit sync wrapper;
}
