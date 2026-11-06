# -----------------------------------------------------------------
# The presets: what `rig repoconfig <preset>` writes into a repo.
#
# Adding one is a line in `descriptions`, an entry in `recommendations` and a
# presets/<name>.toml. The preset names everywhere else (usage, the lookup in
# repoconfig.sh, the prompt hint, completion) come from the `descriptions` keys.
#
# Plain data. default.nix turns it into one store directory per preset.
# -----------------------------------------------------------------

{
  # One line per preset for `--list`.
  descriptions = {
    empty  = "no tools, just the mise.toml and extensions.json skeletons";
    ts     = "node lts, pnpm, typescript; TS plugins; setup task runs pnpm install";
    dotnet = "latest .NET SDK; C# plugin; NuGet lock files; setup task runs dotnet restore";
  };

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
    ];

    dotnet = [
      "ms-dotnettools.csharp"
      # Maybe? ms-dotnettools.csdevkit, verify it installs before adding it
      "Kundros.regexer-extension" # Maybe, we use regex101 mostly
    ];
  };

  # mise.toml is presets/header.toml followed by presets/<name>.toml. These are
  # copied into other people's repos verbatim, so the notes about them are here.
  #
  # ts: pnpm and typescript go through the npm backend rather than the bare
  # shorthands. The shorthand `pnpm` resolves through aqua, which downloads the
  # standalone binary from GitHub releases by asset name, and pnpm's renames of
  # those assets have broken installs before, against a registry snapshot mise
  # bundles per release. The npm backend queries the npm registry over HTTP
  # instead, so that failure mode does not exist. It needs neither node nor an
  # npm CLI to install, and mise orders node first when it is in the same
  # config, so the only requirement is node at runtime, which a JS project has
  # by definition.

  # Preset-specific files beyond mise.toml and extensions.json, by name in the
  # repo root.
  files = {
    # NuGet has no equivalent of pnpm's defaults: nothing holds back a version
    # published an hour ago, and a package's build targets, analyzers and source
    # generators run on every build, in the IDE too. A committed
    # packages.lock.json at least stops a transitive dependency from moving
    # without a diff. Locked mode only in CI, so a local restore can still
    # update the lock file while a mismatch fails the pipeline instead of
    # rewriting it. CI covers GitHub Actions and most others, TF_BUILD covers
    # Azure Pipelines; MSBuild compares case-insensitively.
    #
    # Package source mapping is deliberately not here: with nuget.org as the
    # only feed there is nothing to confuse. It earns its place once a private
    # feed is added.
    #
    # Unlike .git/info/exclude, this is committed, so the comment in it is for
    # the team rather than for me.
    dotnet."Directory.Build.props" = ./presets/Directory.Build.props;
  };
}
