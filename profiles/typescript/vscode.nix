{ pkgs }:

# The list of extensions you want for the TypeScript dev environment.
# Each entry comes from `pkgs.vscode-extensions.<publisher>.<extension>`
# (these are the names used in the upstream nixpkgs collection).

(import ../../templates/vscode.nix { inherit pkgs; }) {
  extra = [
    pkgs.vscode-extensions.ms-vscode.vscode-typescript-next
    pkgs.vscode-extensions.ms-toolsai.jupyter
    pgks.vscode-extensions.dbaumer.vscode-eslint
    pgks.vscode-extensions.vitest.explorer
    pgks.vscode-extensions.yoavbls.pretty-ts-errors
    pgks.vscode-extensions.wix.vscode-import-cost
    pgks.vscode-extensions.meganrogge.template-string-converter
    pgks.vscode-extensions.pflannery.vscode-versionlens # or Pilaton.vscode-npm-lens
    # Maybe? https://marketplace.visualstudio.com/items?itemName=bradgashler.htmltagwrap
    # Maybe? https://marketplace.visualstudio.com/items?itemName=statelyai.stately-vscode # no use for it yet
    pgks.vscode-extensions.rodsarhan.tstypecolorpreview
    pgks.vscode-extensions.Kundros.regexer-extension # Maybe, we use regex101 mostly
    pgks.vscode-extensions.AntiAntiSepticeye.vscode-color-picker
  ];
}