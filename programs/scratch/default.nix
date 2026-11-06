# -----------------------------------------------------------------
# `scratch` -- a throwaway repo with a preset applied, for trying something
# in thirty seconds without deciding where it lives.
#
# It is `repoconfig` on a fresh `git init` in a temp directory, then a shell
# in it. Leaving the shell offers to delete it. See docs/scratch.md.
# -----------------------------------------------------------------

{ pkgs, lib, prefix, repoconfig }:

let
  script = import ../../lib/shell-script.nix { inherit pkgs lib; };
in
script.application {
  name = "scratch";
  file = ./scratch.sh;
  runtimeInputs = with pkgs; [ coreutils git ];
  vars = {
    PREFIX = prefix;
    REPOCONFIG = "${repoconfig.repoconfig}/bin/repoconfig";
    PRESET_NAMES = lib.concatStringsSep " " repoconfig.presets;
  };
}
