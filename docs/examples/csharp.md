# C# project

Every file a C# project uses to declare what it needs, and who reads it.

| file | owns | read by |
| --- | --- | --- |
| `mise.toml` | the .NET SDK | mise, and a human as an SBOM |
| `mise.lock` | the exact resolved version | mise, on every machine |
| `global.json` | the SDK version | the dotnet CLI natively |
| `**/*.csproj` | package references | dotnet, NuGet |
| `.vscode/extensions.json` | the project's plugins | VSCode natively |

Start with `repoconfig dotnet you@example.com`, which writes the first, second
and last.

## mise.toml

```toml
# This file serves both as an auto install and an SBOM (https://www.ntia.gov/page/software-bill-materials)
# Install mise or use this file to configure the tools for this repo
# https://mise.jdx.dev/

[tools]
dotnet = "latest"

# [_.vscode]
# .vscode/extensions.json

# [_.dotnet]
# global.json

[tasks.setup]
description = "First run after cloning"
run = ["dotnet restore"]
```

`dotnet` takes `latest` or a version. It has no `lts` alias, that is node only.

## mise.lock

Committed, and created by `repoconfig` rather than by mise, which only maintains
a lockfile that already exists.

```toml
[[tools.dotnet]]
version = "10.0.400"
backend = "core:dotnet"
```

## global.json

```json
{
  "sdk": {
    "version": "10.0.400"
  }
}
```

The pin that matters to other people. The dotnet CLI reads it natively, so a
contributor gets the same SDK without mise, the same way `packageManager` works
for pnpm. Generate it with `dotnet new globaljson`.

`rollForward` controls how strict it is, if pinning an exact patch turns out to
be too tight.

## .vscode/extensions.json

```jsonc
{
  // comments and trailing commas are legal, this file is JSONC
  "recommendations": [
    "ms-dotnettools.csharp",
  ],
  "unwantedRecommendations": []
}
```

`ms-dotnettools.csdevkit` is the other obvious candidate. Check it installs
before adding it, since `code --install-extension` exits 0 whether or not it
worked:

```bash
code --install-extension ms-dotnettools.csdevkit --force
```

That also catches unsigned extensions, which VSCode refuses outright and which
cannot be allowed per-extension.

## Verifying

```bash
mise run setup
dotnet build
dotnet run
```

The SDK is an ordinary vendor build, so it only runs because `programs.nix-ld`
provides the libraries it expects. That was tested end to end: install, restore,
build and run all work with nothing set per project.

> [!IMPORTANT]
> `ldd` will tell you `libstdc++.so.6 => not found` on a working install. It
> resolves against the standard search paths, while nix-ld works at runtime
> through a loader shim reading `NIX_LD_LIBRARY_PATH`. Use
> `LD_LIBRARY_PATH="$NIX_LD_LIBRARY_PATH" ldd <binary>` or do not run it.

TLS works too. An `HttpClient` call against an https URL returns a response,
which exercises the `openssl` and `zlib` entries in `lib/nix-ld-libs.nix` that a
hello world never touches.

`krb5` in that list stays unexercised. It is only used for Windows domain
authentication, so it is unlikely to come up.
