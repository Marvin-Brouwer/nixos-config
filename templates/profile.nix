{ pkgs, lib }:

{ profile }:

let
  # Packages that appear in *every* dev shell
  defaultPackages = with pkgs; [
    git
    gh
    curl
    jq
    htop
  ];

  # Merge the caller-supplied packages with the defaults
  allPackages = defaultPackages ++ profile.packages;

  # Global env vars + anything the caller adds/overrides
  defaultEnv = {
    EDITOR = "code -w";   # use the VS Code binary as editor
    LANG   = "en_US.UTF-8";
  };
  finalEnv = defaultEnv // (profile.env or {});
in
# mkShell treats unknown string attributes as environment variables,
# so merging finalEnv directly exports all env vars (EDITOR, LANG,
# NODE_OPTIONS, etc.) into the shell.
pkgs.mkShell (finalEnv // {
  name = "dev-shell-${builtins.currentSystem}";
  packages = allPackages;
})
