{ pkgs, ... }:

let
  shared = import ../../main.nix { inherit pkgs; };

  # VSCODE extensions
  extensions = import ./vscode.nix { inherit pkgs; };
  vscodeWithExt = pkgs.vscode-with-extensions.override {
    vscodeExtensions = extensions;
  };
in
pkgs.mkShell {
  name = "typescript-shell";

  packages = shared.commonPackages -- [
    pkgs.vscode
  ] ++ [
    vscodeWithExt

    pkgs.nodejs-20_x
    pkgs.typescript
    pkgs.eslint
    pkgs.npm
    pkgs.pnpm
    pkgs.esbuild
  ];

  # Inherit shared env vars and add a few TS‑specific ones
  inherit (shared.env) EDITOR LANG;
  NODE_OPTIONS = "--max-old-space-size=4096";
}