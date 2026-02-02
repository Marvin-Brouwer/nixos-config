{ pkgs }:

# -----------------------------------------------------------------
# Base list of extensions that you want *every* profile to start with.
# (You can keep this empty if you prefer a truly blank slate.)
# -----------------------------------------------------------------
base = [
  pkgs.vscode-extensions.dbaeumer.vscode-eslint
  pkgs.vscode-extensions.esbenp.prettier-vscode
];

{ extra ? [] }:

vscodeWithExt = pkgs.vscode-with-extensions.override {
  vscodeExtensions = base ++ extra;
};