{ pkgs, lib, ... }:

(import ../../templates/profile.nix { inherit pkgs lib; }) {
  profile = {
    name = "default";
    packages = [];
    extensions = import ../../templates/vscode.nix {};
    env = {};
  };
}
