{ pkgs }:

# The list of extensions you want for the TypeScript dev environment.
# Each entry comes from `pkgs.vscode-extensions.<publisher>.<extension>`
# (these are the names used in the upstream nixpkgs collection).

(import ../../templates/vscode.nix { inherit pkgs; }) {
  extra = [
    pkgs.vscode-extensions.ms-vscode.vscode-typescript-next
    pkgs.vscode-extensions.ms-toolsai.jupyter
    pkgs.vscode-extensions.dbaumer.vscode-eslint
    pkgs.vscode-extensions.vitest.explorer
    pkgs.vscode-extensions.yoavbls.pretty-ts-errors
    pkgs.vscode-extensions.wix.vscode-import-cost
    pkgs.vscode-extensions.meganrogge.template-string-converter
    pkgs.vscode-extensions.pflannery.vscode-versionlens # or Pilaton.vscode-npm-lens
    # Maybe? https://marketplace.visualstudio.com/items?itemName=bradgashler.htmltagwrap
    # Maybe? https://marketplace.visualstudio.com/items?itemName=statelyai.stately-vscode # no use for it yet
    pkgs.vscode-extensions.rodsarhan.tstypecolorpreview
    pkgs.vscode-extensions.Kundros.regexer-extension # Maybe, we use regex101 mostly
    pkgs.vscode-extensions.AntiAntiSepticeye.vscode-color-picker
  ];
}