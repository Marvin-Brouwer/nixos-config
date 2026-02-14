{ pkgs }:

# The list of extensions you want for the TypeScript dev environment.
# Each entry comes from `pkgs.vscode-extensions.<publisher>.<extension>`
# or `pkgs.vscode-marketplace.<publisher>.<extension>` for marketplace-only ones.

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
    pkgs.vscode-marketplace.pflannery.vscode-versionlens # or Pilaton.vscode-npm-lens
    # Maybe? https://marketplace.visualstudio.com/items?itemName=bradgashler.htmltagwrap
    # Maybe? https://marketplace.visualstudio.com/items?itemName=statelyai.stately-vscode # no use for it yet
    pkgs.vscode-marketplace.rodsarhan.tstypecolorpreview
    pkgs.vscode-marketplace.kundros.regexer-extension # Maybe, we use regex101 mostly
    pkgs.vscode-marketplace.antiantisepticeye.vscode-color-picker
  ];
}
