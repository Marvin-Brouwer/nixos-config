{ pkgs }:

# The list of extensions for the TypeScript dev environment.

(import ../../templates/vscode.nix { inherit pkgs; }) {
  extra = [
    # --- Available in nixpkgs ---
    pkgs.vscode-extensions.ms-toolsai.jupyter
    pkgs.vscode-extensions.yoavbls.pretty-ts-errors
    pkgs.vscode-extensions.wix.vscode-import-cost
    pkgs.vscode-extensions.meganrogge.template-string-converter
    # dbaeumer.vscode-eslint is already in the base template

    # --- From marketplace (via nix-vscode-extensions overlay) ---
    pkgs.vscode-marketplace.ms-vscode.vscode-typescript-next
    pkgs.vscode-marketplace.vitest.explorer
    pkgs.vscode-marketplace.pflannery.vscode-versionlens
    pkgs.vscode-marketplace.rodsarhan.tstypecolorpreview
    pkgs.vscode-marketplace.kundros.regexer-extension
    pkgs.vscode-marketplace.antiantisepticeye.vscode-color-picker
  ];
}
