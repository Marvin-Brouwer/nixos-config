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
    # This file serves both as an auto install and an SBOM (https://www.ntia.gov/page/software-bill-materials)
    # Install mise or use this file to configure the tools for this repo
    # https://mise.jdx.dev/

  '';

  # VSCode plugins the *project* wants, which is not the same list as the ones I
  # want everywhere. Mine live in programs/vscode-plugins.nix and never go into
  # someone else's repository; these are the ones a contributor also benefits
  # from, which is why they belong in the standard .vscode/extensions.json.
  #
  # The comments are kept here and stripped on the way out: notes about what I
  # might drop later are mine, and have no business in a repo other people read.
  recommendations = {
    empty = [ ];

    ts = [
      "ms-vscode.vscode-typescript-next"
      "ms-toolsai.jupyter"
      # dbaeumer.vscode-eslint is already in the base template
      "vitest.explorer"
      "yoavbls.pretty-ts-errors"
      "wix.vscode-import-cost"
      "meganrogge.template-string-converter"
      "pflannery.vscode-versionlens" # or Pilaton.vscode-npm-lens
      # Maybe? https://marketplace.visualstudio.com/items?itemName=bradgashler.htmltagwrap
      # Maybe? https://marketplace.visualstudio.com/items?itemName=statelyai.stately-vscode # no use for it yet
      "rodsarhan.tstypecolorpreview"
      "Kundros.regexer-extension" # Maybe, we use regex101 mostly
      "AntiAntiSepticeye.vscode-color-picker"
    ];

    dotnet = [
      "ms-dotnettools.csharp"
      # Maybe? ms-dotnettools.csdevkit, verify it installs before adding it
      "Kundros.regexer-extension" # Maybe, we use regex101 mostly
      "AntiAntiSepticeye.vscode-color-picker"
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


      # [_.vscode]
      # .vscode/extensions.json
    '');

    ts = pkgs.writeText "mise-ts.toml" (tomlHeader + ''
      [tools]
      "npm:pnpm" = "latest"
      node = "lts"
      "npm:typescript" = "latest"

      # [_.vscode]
      # .vscode/extensions.json

      [tasks.setup]
      description = "First run after cloning"
      run = [
        "pnpm install",
        # `playwright install` with no arguments fetches chromium, firefox and
        # webkit. Naming one skips two large downloads. Commented out because
        # not every project has playwright, and pnpm exec would fail.
        # "pnpm exec playwright install chromium",
      ]
    '');

    dotnet = pkgs.writeText "mise-dotnet.toml" (tomlHeader + ''
      [tools]
      dotnet = "latest"

      # [_.vscode]
      # .vscode/extensions.json

      # [_.dotnet]
      # global.json

      [tasks.setup]
      description = "First run after cloning"
      run = ["dotnet restore"]
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
