# -----------------------------------------------------------------
# `doctor` -- one command for "something is off", which checks every piece
# this setup leans on and says, per piece, whether it is fine.
#
# The failures this box has are rarely loud. nix-ld missing makes node fail
# to start with a linker error; a sysupdate timer that stopped firing just
# means no notice, which looks the same as nothing to update. So this asks
# each piece directly rather than waiting for a symptom.
#
# Read-only: it changes nothing and starts nothing, so it is always safe to
# run. Each failure names the command that fixes or explains it.
# See docs/doctor.md.
# -----------------------------------------------------------------

{ pkgs, lib, isWsl, prefix, sysupdateStateDir, compact }:

let
  script = import ../../lib/shell-script.nix { inherit pkgs lib; };
in
script.application {
  name = "doctor";
  file = ./doctor.sh;
  # mise, gpg, docker and the Windows binaries are what is being checked, so
  # they are looked up on your PATH rather than provided here.
  runtimeInputs = with pkgs; [ coreutils gawk gnugrep systemd curl git util-linux ];
  inline = {
    PARTS = ./doctor.d;
    HIGHLIGHT = ../../lib/highlight.sh;
  };
  vars = {
    PREFIX = prefix;
    IS_WSL = if isWsl then "1" else "";
    SYSUPDATE_STATE_DIR = sysupdateStateDir;
    COMPACT_STATE_DIR = compact.stateDir;
    VHD_CHECK = "${compact.vhd}/bin/compact-vhd";
  };
}
