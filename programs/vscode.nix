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
# There is one extension set, not one per repo. VSCode profiles cannot be used
# here: `code --profile <name> --install-extension` will not create a profile
# that does not exist, it just reports "Profile not found" and exits 0
# (microsoft/vscode#176372). The only way to create one is to open a window,
# which a directory change has no business doing. The WSL `code` wrapper has
# never supported --profile either, so that half was always a single set.
#
# The consequence is churn: moving between repos with different plugins
# installs and uninstalls the difference each time.
# -----------------------------------------------------------------

{ pkgs, lib }:

let
  basePlugins = import ./vscode-plugins.nix;

  # .vscode/extensions.json is JSONC: comments and trailing commas are
  # legal and worth keeping, which rules out jq.
  python = pkgs.python3.withPackages (ps: [ ps.json5 ]);

  repoRoot = ''
    repo_root() {
      ${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd
    }
  '';

  sync = pkgs.writeShellScriptBin "vscode-sync" ''
    ${repoRoot}

    MARKER_DIR="''${HOME}/.config/nixos-vscode-sync"
    LOCK_FILE="''${MARKER_DIR}/sync.lock"
    LOG_FILE="''${MARKER_DIR}/last.log"
    ${pkgs.coreutils}/bin/mkdir -p "$MARKER_DIR"

    # The mise hook passes --detach so entering a directory never waits on the
    # network. Run by hand there is no reason to hide: staying in the foreground
    # means you see what it does and know when it is finished.
    DETACH=""
    if [ "''${1:-}" = "--detach" ]; then
      DETACH=1
      shift
    fi

    # `vscode-sync --wait` blocks until a sync started by the hook has finished,
    # so there is something to run before opening VSCode rather than guessing
    # from scrollback.
    if [ "''${1:-}" = "--wait" ]; then
      if ! ${pkgs.util-linux}/bin/flock -n "$LOCK_FILE" true; then
        echo "[vscode] Waiting for the running sync to finish..."
      fi
      ${pkgs.util-linux}/bin/flock "$LOCK_FILE" true
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
    if ! ${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      exit 0
    fi

    REPO_ROOT="$(repo_root)"
    if [ ! -f "$REPO_ROOT/mise.toml" ] && [ ! -f "$REPO_ROOT/.mise.toml" ]; then
      exit 0
    fi

    REPO_NAME="$(${pkgs.coreutils}/bin/basename "$REPO_ROOT")"
    EXT_FILE="$REPO_ROOT/.vscode/extensions.json"

    # One marker, not one per repo. The installed set is global, so a per-repo
    # marker would fast-path out on returning to a repo whose plugins another
    # repo had since uninstalled.
    MARKER_FILE="''${MARKER_DIR}/installed.hash"

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
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
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
        if ! echo "$installed" | ${pkgs.gnugrep}/bin/grep -qx "$ext"; then
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
        (cd /mnt/c && cmd.exe /c code "$@") | ${pkgs.coreutils}/bin/tr -d '\r'
      }

      echo "[vscode] Syncing Windows extensions for $REPO_NAME..."
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

      report_missing win "$(win_code --list-extensions 2>/dev/null | ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]')"
    fi

    # --- WSL side: install into the VS Code remote server ---
    if command -v code >/dev/null 2>&1; then
      echo "[vscode] Syncing WSL extensions for $REPO_NAME..."
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

      report_missing wsl "$(code --list-extensions 2>/dev/null | ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]')"
    fi

    # Only record the hash if everything landed, so a failure retries next time.
    if [ "$FAIL" -eq 0 ]; then
      printf '%s\n' "$DESIRED_HASH" > "$MARKER_FILE"
      echo "[vscode] Extensions are up to date for $REPO_NAME."
    else
      echo "[vscode] Some plugins did not install. Will retry next time."
    fi
  '';

in
sync
