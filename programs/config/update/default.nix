# -----------------------------------------------------------------
# `config update` -- back to main: switch ~/nixos-config to it, fast-forward
# it to the remote, and `config build` when that changed anything.
#
# Fast-forward only, from a clean tree: a merge, rebase or stash is a decision
# to make by hand, not something to do on the way to a rebuild. Its steps are
# update.d/, sourced in order. See docs/config.md.
# -----------------------------------------------------------------

{ pkgs, lib, prefix, build, sysupdateStateDir }:

let
  script = import ../../../lib/shell-script.nix { inherit pkgs lib; };
in
script.application {
  name = "config-update";
  file = ./update.sh;
  runtimeInputs = with pkgs; [ coreutils git ];
  inline = {
    HIGHLIGHT = ../../../lib/highlight.sh;
    CONFIG_REPO = ../../../lib/config-repo.sh;
    PARTS = ./update.d;
  };
  vars = {
    PREFIX = prefix;
    # Where update always goes back to.
    REMOTE = "origin";
    BRANCH = "main";
    BUILD = "${build}/bin/config-build";
    SYSUPDATE_STATE_DIR = sysupdateStateDir;
  };
}
