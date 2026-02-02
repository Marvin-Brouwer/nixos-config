{ pkgs, lib }:

{ profile }:

let
  # Packages that appear in *every* dev shell
  defaultPackages = with pkgs; [
    git
    curl
    jq
    htop
  ];

  # Merge the caller‑supplied packages with the defaults
  allPackages = defaultPackages ++ profile.packages;

  # Global env vars + anything the caller adds/overrides
  defaultEnv = {
    EDITOR = "code -w";   # use the VS Code binary as editor
    LANG   = "en_US.UTF-8";
  };
  finalEnv = defaultEnv // (profile.env or {});
in
pkgs.mkShell {
  name = "dev-shell-${builtins.currentSystem}";
  packages = allPackages;

  # Export the environment variables.  Any key that isn’t a known
  # mkShell attribute becomes an env‑var automatically.
  inherit (finalEnv) EDITOR LANG;
  inherit finalEnv;   # forwards any extra keys (e.g. NODE_OPTIONS)
}