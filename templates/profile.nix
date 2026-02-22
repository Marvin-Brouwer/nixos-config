{ pkgs, lib }:

{ profile }:

let
  # Packages that appear in *every* dev shell
  defaultPackages = with pkgs; [
    git
    gh
    curl
    jq
    htop
  ];

  # Merge the caller-supplied packages with the defaults
  allPackages = defaultPackages ++ profile.packages;

  # Global env vars + anything the caller adds/overrides
  defaultEnv = {
    EDITOR = "code -w";   # use the VS Code binary as editor
    LANG   = "en_US.UTF-8";
  };
  finalEnv = defaultEnv // (profile.env or {});

  # VSCode extension management
  profileName = profile.name or "default";
  extensions = profile.extensions or [];

  # Script that syncs VSCode extensions into the named Windows-side profile.
  # Runs in the background so it doesn't block shell startup.
  # Uses cmd.exe from /mnt/c to call the Windows VS Code CLI directly,
  # which supports --profile for extension management (the WSL `code`
  # wrapper does not). Must cd to /mnt/c first because cmd.exe cannot
  # handle UNC paths (\\wsl.localhost\...) as working directory.
  syncExtensionsScript = pkgs.writeShellScript "sync-vscode-extensions" ''
    DESIRED_EXTS="${lib.concatStringsSep "\n" (map lib.toLower extensions)}"
    MARKER_DIR="''${HOME}/.config/nixos-vscode-profiles"
    MARKER_FILE="''${MARKER_DIR}/${profileName}.hash"
    DESIRED_HASH=$(echo "$DESIRED_EXTS" | ${pkgs.coreutils}/bin/sha256sum | cut -d' ' -f1)

    mkdir -p "$MARKER_DIR"

    # Skip if extensions haven't changed
    if [ -f "$MARKER_FILE" ] && [ "$(cat "$MARKER_FILE")" = "$DESIRED_HASH" ]; then
      exit 0
    fi

    FAIL=0

    # --- Windows side: install into the named VS Code profile ---
    if command -v cmd.exe >/dev/null 2>&1; then
      # cmd.exe cannot handle UNC paths so we cd to /mnt/c first
      win_code() {
        (cd /mnt/c && cmd.exe /c code --profile "${profileName}" "$@") | tr -d '\r'
      }

      # Ensure the profile exists
      win_code --list-extensions >/dev/null 2>&1

      echo "[vscode] Syncing Windows profile '${profileName}'..."
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
    fi

    # --- WSL side: install into the VS Code remote server ---
    if command -v code >/dev/null 2>&1; then
      echo "[vscode] Syncing WSL remote extensions..."
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
    fi

    # Only write hash if all installs succeeded
    if [ "$FAIL" -eq 0 ]; then
      echo "$DESIRED_HASH" > "$MARKER_FILE"
      echo "[vscode] Profile '${profileName}' is up to date."
    else
      echo "[vscode] Some extensions failed to install. Will retry next time."
    fi
  '';

  # Wrapper script: opens VSCode with the named profile.
  # Must be a real script (not a shell function) because direnv only
  # captures environment variables, not functions.
  # Script that ensures Windows VSCode uses this WSL distro as the default terminal.
  # Writes to the global VSCode user settings on the Windows side.
  # Only runs once (marker file tracks completion).
  ensureTerminalScript = pkgs.writeShellScript "ensure-vscode-terminal" ''
    if ! command -v cmd.exe >/dev/null 2>&1; then
      exit 0
    fi

    MARKER_DIR="''${HOME}/.config/nixos-vscode-profiles"
    MARKER_FILE="''${MARKER_DIR}/terminal-configured"
    if [ -f "$MARKER_FILE" ]; then
      exit 0
    fi

    # Find Windows APPDATA via cmd.exe
    WIN_APPDATA=$(cd /mnt/c && cmd.exe /c "echo %APPDATA%" 2>/dev/null | tr -d '\r')
    # Convert Windows path to WSL path: C:\Users\... -> /mnt/c/Users/...
    WSL_APPDATA=$(echo "$WIN_APPDATA" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/mnt/\L\1|')
    SETTINGS_FILE="$WSL_APPDATA/Code/User/settings.json"

    if [ ! -f "$SETTINGS_FILE" ]; then
      mkdir -p "$(dirname "$SETTINGS_FILE")"
      echo '{}' > "$SETTINGS_FILE"
    fi

    DISTRO="''${WSL_DISTRO_NAME:-NixOS}"

    # Merge terminal profile definition and set it as default
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
      && mv "''${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

    mkdir -p "$MARKER_DIR"
    touch "$MARKER_FILE"
    echo "[vscode] Set default terminal to '$DISTRO (WSL)'."
  '';

  # Wrapper script: opens VSCode with the named profile.
  # Must be a real script (not a shell function) because direnv only
  # captures environment variables, not functions.
  vscodeWrapper = pkgs.writeShellScriptBin "vscode" ''
    if [ $# -eq 0 ]; then
      exec code --profile "${profileName}" .
    else
      exec code --profile "${profileName}" "$@"
    fi
  '';

in
# mkShell treats unknown string attributes as environment variables,
# so merging finalEnv directly exports all env vars (EDITOR, LANG,
# NODE_OPTIONS, etc.) into the shell.
pkgs.mkShell (finalEnv // {
  name = "dev-shell-${pkgs.system}";
  packages = allPackages ++ [ vscodeWrapper ];
  shellHook = ''
    # Ensure Windows VSCode defaults to this WSL distro as terminal
    ${ensureTerminalScript} &
  '' + lib.optionalString (extensions != []) ''
    # Sync VSCode extensions in the background
    ${syncExtensionsScript} &
  '';
})
