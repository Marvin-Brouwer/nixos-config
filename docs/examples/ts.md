# TypeScript project

Every file a TypeScript project uses to declare what it needs, and who reads it.

| file | owns | read by |
| --- | --- | --- |
| `mise.toml` | node, pnpm, typescript | mise, and a human as an SBOM |
| `mise.lock` | the exact resolved versions | mise, on every machine |
| `package.json` | dependencies, the pnpm version, setup steps | pnpm, npm, CI, everyone |
| `.vscode/extensions.json` | the project's plugins | VSCode natively |
| `playwright.config.ts` | which browsers the suite uses | playwright |

Start with `repoconfig ts you@example.com`, which writes the first, second and
fourth. The rest come from the project.

## mise.toml

```toml
# This file serves both as an auto install and an SBOM (https://www.ntia.gov/page/software-bill-materials)
# Install mise or use this file to configure the tools for this repo
# https://mise.jdx.dev/

[tools]
"npm:pnpm" = "latest"
node = "lts"
"npm:typescript" = "latest"

# [_.vscode]
# .vscode/extensions.json

[tasks.setup]
description = "First run after cloning"
run = ["pnpm install"]
```

`node` is the only tool that accepts `lts`. Everything else takes `latest` or a
version.

pnpm and typescript come from the npm backend rather than the bare shorthands.
The shorthand `pnpm` resolves through aqua, which fetches the standalone binary
from GitHub releases by asset name, and pnpm has renamed those assets before
against a registry snapshot mise bundles per release. The npm backend queries the
npm registry over HTTP instead, so that cannot happen. It needs neither node nor
an npm CLI to install.

## mise.lock

Committed, and not written by hand. `repoconfig` creates it, because mise will
not: it only maintains a lockfile that already exists, and says nothing when
there is none.

It records the exact version and a checksum per platform, which is what makes two
machines install the same artifact rather than the same version range:

```toml
[[tools.node]]
version = "24.20.0"
backend = "core:node"

[tools.node."platforms.linux-x64"]
checksum = "sha256:855d581f8a4eb..."
url = "https://nodejs.org/dist/v24.20.0/node-v24.20.0-linux-x64.tar.gz"
```

`mise up` bumps it when you decide to.

## package.json

```json
{
  "packageManager": "pnpm@10.34.5",
  "scripts": {
    "postinstall": "playwright install chromium"
  }
}
```

`packageManager` is the pin that matters to other people. pnpm reads it and
switches itself to that version, because `manage-package-manager-versions` is on
by default, so a contributor gets the same pnpm without corepack and without
mise. mise installs a pnpm to bootstrap with; this decides which one actually
runs.

> [!NOTE]
> pnpm's update banner suggests `corepack use pnpm@x`. That does nothing here,
> since corepack is not part of this setup. The upgrade path is `mise use pnpm@x`
> plus updating `packageManager`.

`postinstall` is where Playwright's browsers belong rather than in the mise
`setup` task: it runs for contributors and in CI without either knowing about
mise. Name the browser, because `playwright install` with no arguments fetches
chromium, firefox and webkit.

Playwright itself stays a devDependency. It resolves browsers by revision number
tied to its own version, so a globally installed one would download browsers the
project's copy does not look for.

## .vscode/extensions.json

```jsonc
{
  // comments and trailing commas are legal, this file is JSONC
  "recommendations": [
    "ms-vscode.vscode-typescript-next",
    "vitest.explorer",
    "yoavbls.pretty-ts-errors",
  ],
  "unwantedRecommendations": []
}
```

The standard file. VSCode prompts anyone who opens the folder, and `vscode-sync`
unions it with the base list in `programs/vscode-plugins.nix`, minus anything in
`unwantedRecommendations`.

Put project plugins here and personal ones in the base list. Anything in neither
gets uninstalled.

## Verifying

```bash
mise run setup
pnpm exec playwright test
```

Playwright works with nothing set per project: `programs.nix-ld` makes the
downloaded browsers runnable, and `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS` is
set system-wide because Playwright refuses to recognise NixOS otherwise.

If a browser will not launch, `playwright-fhs` is a sandbox where the downloaded
binaries run unmodified. It has never been needed for chromium.
