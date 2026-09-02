# -----------------------------------------------------------------
# `repoconfig <preset> <email>` -- set a repo up for this machine.
#
# Everything here fails silently if skipped, which is why it is one command
# rather than a list in the Readme:
#
#   * mise will not load a config it has not been told to trust, so nothing
#     downstream of that works until it is trusted.
#   * mise never creates a lockfile. It only maintains one that already
#     exists, and says nothing when there is none, so a repo without it
#     silently gets no version pinning at all.
#   * `mise install` records versions; `mise lock` is what adds the checksums
#     and URLs that make the file worth committing.
#   * vscode-sync uses the presence of mise.toml to decide a directory is a
#     managed repo, so without one a project gets no plugin sync either.
#
# Presets differ only in what goes into mise.toml and .vscode/extensions.json.
# -----------------------------------------------------------------

{ pkgs, lib }:

let
  gitUserName = "Marvin Brouwer";

  tomlHeader = ''
    # This file serves both as an auto install and an SBOM
    # (https://www.ntia.gov/page/software-bill-materials).
    # Install mise, or read this file to configure the tools for this repo by
    # hand. https://mise.jdx.dev/
    #
    # Only `node` supports "lts". Everything else takes "latest" or a version.

  '';

  # VSCode plugins the *project* wants, which is not the same list as the ones
  # I want everywhere. Mine live in programs/vscode-plugins.nix and never go
  # into a repo; these are the ones a contributor also benefits from, which is
  # why they belong in the standard .vscode/extensions.json instead.
  recommendations = {
    empty = [ ];

    ts = [
      "dbaeumer.vscode-eslint"
      "esbenp.prettier-vscode"
      "ms-vscode.vscode-typescript-next"
      "vitest.explorer"
      "yoavbls.pretty-ts-errors"
      "wix.vscode-import-cost"
      "meganrogge.template-string-converter"
      "pflannery.vscode-versionlens"
      "rodsarhan.tstypecolorpreview"
      "AntiAntiSepticeye.vscode-color-picker"
      "Kundros.regexer-extension"
    ];

    dotnet = [
      "ms-dotnettools.csharp"
      "editorconfig.editorconfig"
      "AntiAntiSepticeye.vscode-color-picker"
      "Kundros.regexer-extension"
    ];
  };

  # pnpm and typescript go through the npm backend rather than the bare
  # shorthands. The shorthand `pnpm` resolves through aqua, which downloads the
  # standalone binary from GitHub releases by asset name, and pnpm's renames of
  # those assets have broken installs before, against a registry snapshot mise
  # bundles per release. The npm backend queries the npm registry over HTTP
  # instead, so that failure mode does not exist. It needs neither node nor an
  # npm CLI to install, and mise orders node first when it is in the same
  # config, so the only requirement is node at runtime, which a JS project has
  # by definition.
  miseToml = {
    empty = pkgs.writeText "mise-empty.toml" (tomlHeader + ''
      [tools]


      # VSCode plugins for this repo live in .vscode/extensions.json
    '');

    ts = pkgs.writeText "mise-ts.toml" (tomlHeader + ''
      [tools]
      node = "lts"
      "npm:pnpm" = "latest"
      "npm:typescript" = "latest"

      # VSCode plugins for this repo live in .vscode/extensions.json

      # Inert metadata. mise never parses anything under [_], so this documents
      # the browsers the suite needs without pretending to install them;
      # playwright.config.ts is what actually drives `playwright install`.
      [_.playwright]
      engines = ["chromium"]
    '');

    dotnet = pkgs.writeText "mise-dotnet.toml" (tomlHeader + ''
      [tools]
      dotnet = "latest"

      # VSCode plugins for this repo live in .vscode/extensions.json
      #
      # global.json pins the SDK for contributors who do not run mise; the
      # dotnet CLI reads it natively.
    '');
  };

  extensionsJson = lib.mapAttrs (name: exts:
    pkgs.writeText "extensions-${name}.json" (builtins.toJSON {
      recommendations = exts;
      unwantedRecommendations = [ ];
    })
  ) recommendations;

in
pkgs.writeShellScriptBin "repoconfig" ''
  set -uo pipefail

  PRESET="''${1:-}"
  EMAIL="''${2:-}"

  say()  { printf '   %s\n' "$*"; }
  made() { printf '   \033[1;32mcreated\033[0m %s\n' "$*"; }
  kept() { printf '   \033[1;33mkept\033[0m    %s (already present)\n' "$*"; }
  die()  { printf '\033[1;31mrepoconfig:\033[0m %s\n' "$*" >&2; exit 1; }

  case "$PRESET" in
    empty)  MISE_SRC=${miseToml.empty};  EXT_SRC=${extensionsJson.empty}  ;;
    ts)     MISE_SRC=${miseToml.ts};     EXT_SRC=${extensionsJson.ts}     ;;
    dotnet) MISE_SRC=${miseToml.dotnet}; EXT_SRC=${extensionsJson.dotnet} ;;
    *) die "usage: repoconfig <empty|ts|dotnet> <email>" ;;
  esac
  [ -n "$EMAIL" ] || die "usage: repoconfig <empty|ts|dotnet> <email>"

  ${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git repository"
  REPO_ROOT="$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
  cd "$REPO_ROOT" || die "cannot enter $REPO_ROOT"

  printf '\n\033[1;34m== %s (%s)\033[0m\n' "$(${pkgs.coreutils}/bin/basename "$REPO_ROOT")" "$PRESET"

  # --- git identity ---
  ${pkgs.git}/bin/git config --local user.name "${gitUserName}"
  ${pkgs.git}/bin/git config --local user.email "$EMAIL"
  say "git identity: ${gitUserName} <$EMAIL>"

  # --- mise.toml ---
  if [ -f mise.toml ] || [ -f .mise.toml ]; then
    kept "mise.toml"
  else
    ${pkgs.coreutils}/bin/cp "$MISE_SRC" mise.toml
    ${pkgs.coreutils}/bin/chmod +w mise.toml
    made "mise.toml"
  fi

  # --- trust, before anything reads the config ---
  mise trust >/dev/null 2>&1 && say "mise trust" || say "mise trust: nothing to do"

  # --- lockfile ---
  # mise will not create this itself, and stays silent when it is absent, so a
  # repo without it quietly gets no pinning at all.
  if [ -f mise.lock ]; then
    kept "mise.lock"
  else
    ${pkgs.coreutils}/bin/touch mise.lock
    made "mise.lock"
  fi
  mise install || say "mise install reported a problem, see above"
  mise lock --platform linux-x64,windows-x64 || say "mise lock reported a problem, see above"

  # --- vscode plugins ---
  if [ -f .vscode/extensions.json ]; then
    kept ".vscode/extensions.json"
  else
    ${pkgs.coreutils}/bin/mkdir -p .vscode
    ${pkgs.jq}/bin/jq . "$EXT_SRC" > .vscode/extensions.json
    made ".vscode/extensions.json"
  fi

  # --- local ignores ---
  # .git/info/exclude rather than .gitignore: personal tooling should not turn
  # up in other people's diffs. mise.toml and mise.lock are meant to be
  # committed, so only the local override file is excluded.
  EXCLUDE=".git/info/exclude"
  ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$EXCLUDE")"
  if ${pkgs.gnugrep}/bin/grep -qxF "mise.local.toml" "$EXCLUDE" 2>/dev/null; then
    kept "$EXCLUDE entry"
  else
    printf '%s\n' "mise.local.toml" >> "$EXCLUDE"
    made "$EXCLUDE entry for mise.local.toml"
  fi

  printf '\n   Done. `cd` out and back in to trigger the plugin sync.\n\n'
''
