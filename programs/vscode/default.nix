# -----------------------------------------------------------------
# VSCode plugin sync, triggered by the mise `enter` hook in programs/mise.toml.
# The command itself is sync.sh.
#
# What it installs is the union of two lists:
#
#   * programs/vscode-plugins.nix -- mine, wanted everywhere.
#   * <repo>/.vscode/extensions.json -- the project's, and the standard
#     file VSCode already prompts contributors to install. Nothing here is
#     mise-specific or NixOS-specific, so a contributor gets the same set
#     through their own editor without knowing this exists.
#
# minus that file's `unwantedRecommendations`.
#
# There is one extension set, not one per repo. VSCode profiles cannot be used
# here: `code --profile <name> --install-extension` will not create a profile
# that does not exist, it just reports "Profile not found" and exits 0
# (microsoft/vscode#176372). The only way to create one is to open a window,
# which a directory change has no business doing. The WSL `code` wrapper has
# never supported --profile either, so that half was always a single set.
#
# The consequence is churn: moving between repos with different plugins
# installs and uninstalls the difference each time.
# -----------------------------------------------------------------

{ pkgs, lib, prefix }:

let
  script = import ../../lib/script.nix { inherit lib; };
  basePlugins = import ../vscode-plugins.nix;

  # .vscode/extensions.json is JSONC: comments and trailing commas are
  # legal and worth keeping, which rules out jq.
  python = pkgs.python3.withPackages (ps: [ ps.json5 ]);
in
pkgs.writeShellScriptBin "vscode-sync" (script ./sync.sh {
  inherit prefix python;
  inherit (pkgs) coreutils git gnugrep gnused jq;
  utilLinux = pkgs.util-linux;
  extensionsJson = ./extensions-json.py;
  baseExts = lib.concatStringsSep "\n" (map lib.toLower basePlugins);
})
