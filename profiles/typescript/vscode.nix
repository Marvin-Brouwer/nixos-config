{ pkgs }:

# The list of extensions you want for the TypeScript dev environment.
# Each entry comes from `pkgs.vscode-extensions.<publisher>.<extension>`
# (these are the names used in the upstream nixpkgs collection).

(import ../../templates/vscode.nix { inherit pkgs; }) {
  extra = [
    pkgs.vscode-extensions.ms-vscode.vscode-typescript-next
    pkgs.vscode-extensions.ms-toolsai.jupyter
  ];
}