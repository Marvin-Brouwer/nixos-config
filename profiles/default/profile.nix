{ pkgs, lib, ... }:

(import ../../templates/profile.nix { inherit pkgs lib; }) {
  profile = {
    packages = [
      import ../../templates/vscode.nix { inherit pkgs; };
    ];         
    env = {
      # No exta env settings
    };
  };
}