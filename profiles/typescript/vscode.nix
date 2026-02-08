{ pkgs }:

# The list of extensions for the TypeScript dev environment.
# Extensions not in nixpkgs can be installed via VSCode marketplace.

(import ../../templates/vscode.nix { inherit pkgs; }) {
  extra = [
    pkgs.vscode-extensions.ms-toolsai.jupyter
    pkgs.vscode-extensions.yoavbls.pretty-ts-errors
    pkgs.vscode-extensions.wix.vscode-import-cost
    pkgs.vscode-extensions.meganrogge.template-string-converter
    # dbaeumer.vscode-eslint is already in the base template

    # Not packaged in nixpkgs — install via VSCode marketplace:
    #   ms-vscode.vscode-typescript-next
    #   vitest.explorer
    #   pflannery.vscode-versionlens
    #   rodsarhan.tstypecolorpreview
    #   Kundros.regexer-extension
    #   AntiAntiSepticeye.vscode-color-picker
  ];
}
