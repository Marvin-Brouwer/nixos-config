# `rig repo init ts`: node, pnpm and typescript.
{
  description = "node lts, pnpm, typescript; TS plugins; setup task runs pnpm install";

  # mise-preset.toml is copied into the repo verbatim, so the notes on it are
  # here.
  #
  # pnpm and typescript go through the npm backend rather than the bare
  # shorthands. The shorthand `pnpm` resolves through aqua, which downloads the
  # standalone binary from GitHub releases by asset name, and pnpm's renames of
  # those assets have broken installs before, against a registry snapshot mise
  # bundles per release. The npm backend queries the npm registry over HTTP
  # instead, so that failure mode does not exist. It needs neither node nor an
  # npm CLI to install, and mise orders node first when it is in the same
  # config, so the only requirement is node at runtime, which a JS project has
  # by definition.

  recommendations = [
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
}
