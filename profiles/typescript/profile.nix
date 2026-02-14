{ pkgs, lib, ... }:

(import ../../templates/profile.nix { inherit pkgs lib; }) {
  profile = {
    name = "typescript";
    packages = [
      pkgs.nodejs_24
      pkgs.typescript
      pkgs.eslint
      pkgs.pnpm
      pkgs.esbuild
    ];
    extensions = import ./vscode.nix;
    env = {
      NODE_OPTIONS = "--max-old-space-size=4096";
    };
  };
}
