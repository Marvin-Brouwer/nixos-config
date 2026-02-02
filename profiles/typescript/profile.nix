{ pkgs, lib, ... }:

(import ../../templates/profile.nix { inherit pkgs lib; }) {
  profile = {
    
    packages = [
      pkgs.nodejs-20_x
      pkgs.typescript
      pkgs.eslint
      pkgs.npm
      pkgs.pnpm
      pkgs.esbuild
      import ./vscode.nix { inherit pkgs; };
    ];

    env = {
      NODE_OPTIONS = "--max-old-space-size=4096";
    };
  };
}