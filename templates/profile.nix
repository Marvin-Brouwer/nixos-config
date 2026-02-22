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

  # VSCode profile management
  profileName = profile.name or "default";
  extensions = profile.extensions or [];

  # Script that syncs extensions into the named VSCode profile.
  # Runs in the background so it doesn't block shell startup.
  # Only installs missing extensions; removes extensions not in the list.
  syncExtensionsScript = pkgs.writeShellScript "sync-vscode-extensions" ''
    if ! command -v code >/dev/null 2>&1; then
      exit 0
    fi

    PROFILE="${profileName}"
    DESIRED_EXTS="${lib.concatStringsSep "\n" (map lib.toLower extensions)}"
    MARKER_DIR="''${HOME}/.config/nixos-vscode-profiles"
    MARKER_FILE="''${MARKER_DIR}/''${PROFILE}.hash"
    DESIRED_HASH=$(echo "$DESIRED_EXTS" | ${pkgs.coreutils}/bin/sha256sum | cut -d' ' -f1)

    mkdir -p "$MARKER_DIR"

    # Skip if extensions haven't changed
    if [ -f "$MARKER_FILE" ] && [ "$(cat "$MARKER_FILE")" = "$DESIRED_HASH" ]; then
      exit 0
    fi

    echo "[vscode] Syncing extensions for profile '$PROFILE'..."

    INSTALLED=$(code --profile "$PROFILE" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')

    # Install missing extensions
    for ext in $DESIRED_EXTS; do
      if ! echo "$INSTALLED" | grep -qx "$ext"; then
        echo "[vscode] Installing $ext..."
        code --profile "$PROFILE" --install-extension "$ext" --force 2>/dev/null
      fi
    done

    # Remove extensions not in the desired list
    for ext in $INSTALLED; do
      if ! echo "$DESIRED_EXTS" | grep -qx "$ext"; then
        echo "[vscode] Removing $ext (not in profile)..."
        code --profile "$PROFILE" --uninstall-extension "$ext" 2>/dev/null
      fi
    done

    echo "$DESIRED_HASH" > "$MARKER_FILE"
    echo "[vscode] Profile '$PROFILE' is up to date."
  '';

in
# mkShell treats unknown string attributes as environment variables,
# so merging finalEnv directly exports all env vars (EDITOR, LANG,
# NODE_OPTIONS, etc.) into the shell.
pkgs.mkShell (finalEnv // {
  name = "dev-shell-${pkgs.system}";
  packages = allPackages;
  shellHook = lib.optionalString (extensions != []) ''
    # Sync VSCode extensions in the background
    ${syncExtensionsScript} &

    # Wrap code to always use this profile
    code() {
      command code --profile "${profileName}" "$@"
    }
  '';
})
