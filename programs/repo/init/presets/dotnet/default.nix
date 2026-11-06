# `rig repo init dotnet`: the .NET SDK, with NuGet lock files.
{
  description = "latest .NET SDK; C# plugin; NuGet lock files; setup task runs dotnet restore";

  recommendations = [
    "ms-dotnettools.csharp"
    # Maybe? ms-dotnettools.csdevkit, verify it installs before adding it
    "Kundros.regexer-extension" # Maybe, we use regex101 mostly
  ];

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
    "Directory.Build.props" = ./Directory.Build.props;
  };
}
