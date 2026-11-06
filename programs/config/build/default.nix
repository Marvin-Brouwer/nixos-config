# -----------------------------------------------------------------
# `config build` -- build the branch ~/nixos-config is on and switch to it.
#
# Building is an unprivileged `nix build` first; only the switch asks for sudo,
# and a build that is the system already running stops before it. Its steps
# are build.d/, sourced in order. `config update` runs this after pulling.
# See docs/config.md.
# -----------------------------------------------------------------

{ pkgs, lib, hostName, prefix }:

let
  script = import ../../../lib/shell-script.nix { inherit pkgs lib; };
in
script.application {
  name = "config-build";
  file = ./build.sh;
  # sudo is the system's setuid wrapper, so it comes from your PATH.
  runtimeInputs = with pkgs; [ coreutils git nix nvd nixos-rebuild ];
  inline = {
    HIGHLIGHT = ../../../lib/highlight.sh;
    CONFIG_REPO = ../../../lib/config-repo.sh;
    PARTS = ./build.d;
  };
  vars = {
    HOST_NAME = hostName;
    PREFIX = prefix;
  };
}
