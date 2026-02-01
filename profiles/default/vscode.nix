{ pkgs }:

# The list of extensions you want for the TypeScript dev environment.
# Each entry comes from `pkgs.vscode-extensions.<publisher>.<extension>`
# (these are the names used in the upstream nixpkgs collection).

[
  pkgs.vscode-extensions.mechatroner.rainbow-csv
  jnoortheen.nix-ide
]