{ pkgs, ... }:

let
  # Pull the shared bits if you have a main.nix
  shared = import ../../main.nix { inherit pkgs; };

  # VSCODE extensions
  extensions = import ./vscode.nix { inherit pkgs; };
  vscodeWithExt = pkgs.vscode-with-extensions.override {
    vscodeExtensions = extensions;
  };
in
pkgs.mkShell {
  name = "default-shell";

  packages = shared.commonPackages -- [
    pkgs.vscode
  ] ++ [
    vscodeWithExt
  ];


  # Export the shared env vars (and you can add more)
  inherit (shared.env) EDITOR LANG;
}