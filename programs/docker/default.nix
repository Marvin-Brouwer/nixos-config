# -----------------------------------------------------------------
# `docker` -- stop the Docker daemon, or see whether it runs.
#
# The daemon is socket-activated (enableOnBoot = false in configuration.nix):
# the first `docker` command starts it, so there is no start here. Stopping is
# the part worth a command. An idle daemon, and whatever containers it still
# runs, holds on to memory the WSL VM does not hand back, and stopping only
# docker.service is undone by the next CLI call through docker.socket. This
# stops both, then re-arms the socket, so the next `docker` command still
# starts the daemon on demand.
# -----------------------------------------------------------------

{ pkgs, lib, prefix }:

let
  script = import ../../lib/shell-script.nix { inherit pkgs lib; };
in
script.application {
  # Not `docker`: the script calls the real one by that name.
  name = "docker-daemon";
  file = ./docker.sh;
  # docker itself comes from the system, and sudo is its setuid wrapper.
  runtimeInputs = with pkgs; [ coreutils systemd ];
  inline.HIGHLIGHT = ../../lib/highlight.sh;
  vars.PREFIX = prefix;
}
