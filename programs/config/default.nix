# -----------------------------------------------------------------
# `config` -- working on this repo itself: build a branch of it and switch to
# it, or go back to main and pull. Two commands, grouped under `config` in
# configuration.nix:
#
#   config build    build.sh   build the checkout's branch, diff, switch
#                   (its steps are build.d/, sourced in order)
#   config update   update.sh  switch to main, fast-forward it to the remote,
#                              and `config build` when that changed anything
#                   (its steps are update.d/)
#
# Building is an unprivileged `nix build` first;
# only the switch asks for sudo, and a build that is the system already
# running stops before it. update is fast-forward only, from a clean tree:
# a merge, rebase or stash is a decision to make by hand, not something to do
# on the way to a rebuild. See docs/config.md.
# -----------------------------------------------------------------

{ pkgs, lib, hostName, prefix, sysupdateStateDir }:

let
  script = import ../../lib/shell-script.nix { inherit pkgs lib; };

  highlight = ../../lib/highlight.sh;
  configRepo = ../../lib/config-repo.sh;

  build = script.application {
    name = "config-build";
    file = ./build.sh;
    # sudo is the system's setuid wrapper, so it comes from your PATH.
    runtimeInputs = with pkgs; [ coreutils git nix nvd nixos-rebuild ];
    inline = {
      HIGHLIGHT = highlight;
      CONFIG_REPO = configRepo;
      PARTS = ./build.d;
    };
    vars = {
      HOST_NAME = hostName;
      PREFIX = prefix;
    };
  };

  update = script.application {
    name = "config-update";
    file = ./update.sh;
    runtimeInputs = with pkgs; [ coreutils git ];
    inline = {
      HIGHLIGHT = highlight;
      CONFIG_REPO = configRepo;
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
  };
in
{
  inherit build update;
}
