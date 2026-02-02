# templates/vscode.nix
{ pkgs }:

# -----------------------------------------------------------------
# Base list of extensions that all profiles inherit.
# -----------------------------------------------------------------
base = [
  pkgs.vscode-extensions.dbaeumer.vscode-eslint
  pkgs.vscode-extensions.esbenp.prettier-vscode
];

{ extra ? [] }:

pkgs.vscode-with-extensions.override {
  vscodeExtensions = base ++ extra;
}