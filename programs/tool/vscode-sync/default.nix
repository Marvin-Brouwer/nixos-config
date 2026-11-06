# -----------------------------------------------------------------
# VSCode plugin sync, triggered by the mise `enter` hook in programs/mise.toml.
# The command itself is sync.sh, which sources sync.d/ step by step. It gets
# its tools and values from lib/shell-script.nix.
#
# What it installs is the union of two lists:
#
#   * programs/tool/vscode-sync/plugins.nix -- mine, wanted everywhere.
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
  script = import ../../../lib/shell-script.nix { inherit pkgs lib; };
  basePlugins = import ./plugins.nix;

  # .vscode/extensions.json is JSONC: comments and trailing commas are
  # legal and worth keeping, which rules out jq.
  python = pkgs.python3.withPackages (ps: [ ps.json5 ]);
in
script.application {
  name = "vscode-sync";
  file = ./sync.sh;
  runtimeInputs = with pkgs; [ coreutils git gnugrep gnused jq util-linux python ];
  vars = {
    PREFIX = prefix;
    EXTENSIONS_JSON_PY = ./extensions-json.py;
    BASE_EXTS = lib.concatStringsSep "\n" (map lib.toLower basePlugins);
  };
  inline.PARTS = ./sync.d;
}
