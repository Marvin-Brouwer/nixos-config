# The list of extensions for the TypeScript dev environment.
# Extension IDs in publisher.name format (as shown in the marketplace).

(import ../../templates/vscode.nix) {
  extra = [
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
}
