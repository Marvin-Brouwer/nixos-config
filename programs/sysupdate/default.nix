# -----------------------------------------------------------------
# `sysupdate` -- one command to see what is pending and apply it, plus the
# background check and the shell notice that tell you it is pending at all.
#
# Why this exists rather than `system.autoUpgrade`:
#
#   * autoUpgrade activates silently. Seeing what changed and choosing when is
#     the entire point here.
#   * In WSL it also cannot work. The VM idle-terminates once nothing is a
#     child of its init, so a 04:00 timer never fires, and `persistent = true`
#     turns that into a multi-minute rebuild starting the moment you sit down.
#
# On a bare-metal host autoUpgrade is still worth having, for the other half of
# the problem: pointed at the pushed repo it deploys a flake.lock this command
# already decided on, committed and pushed. See docs/sysupdate.md.
#
# Three commands come out of this directory, each its own script:
#
#   sysupdate         sysupdate.sh  bump inputs, build, diff, apply or stage
#                     (its steps are sysupdate.d/, sourced in order)
#   sysupdate-check   check.sh      the background job, run by a systemd timer
#   sysupdate-notice  notice.sh     prints the cached result on shell start
#
# helpers.sh is what the first two share, diff.py renders the notice.
#
# The scripts are plain shell, given their tools on PATH and their values as
# variables by lib/shell-script.nix. `mise run lint` shellchecks them from
# the repo root; the build does too.
#
# Nothing here names a host. `hostName` builds the flake attribute and `isWsl`
# decides the wording and the kernel check, both from configuration.nix, so a
# second machine is two bindings rather than a rewrite.
# -----------------------------------------------------------------

{ pkgs, lib, hostName, isWsl, watch, prefix }:

let
  script = import ../../lib/shell-script.nix { inherit pkgs lib; };

  # Root-owned, world-readable: the check writes it, every shell reads it.
  stateDir = "/var/lib/sysupdate";

  # Reads as "<hint> to activate it." Deliberately backtick-free: this ends up
  # inside a double-quoted shell string, where a backtick is a command
  # substitution and `wsl` is not a command that exists in here.
  rebootHint =
    if isWsl
    then "Run 'wsl --shutdown' from Windows and start it again"
    else "Reboot";

  python = pkgs.python3;
  diff = ./diff.py;

  # What both scripts that source helpers.sh need, for it and for themselves.
  shared = {
    STATE_DIR = stateDir;
    HOST_NAME = hostName;
    PREFIX = prefix;
    REBOOT_HINT = rebootHint;
    DIFF_PY = diff;
  };

  check = script.application {
    name = "sysupdate-check";
    file = ./check.sh;
    runtimeInputs = with pkgs; [ coreutils git nix jq gnugrep python ];
    inline.HELPERS = ./helpers.sh;
    vars = shared // {
      # Names the notice is allowed to spell out, from the same list that builds
      # environment.systemPackages, so the two cannot drift apart.
      WATCH = lib.concatStringsSep "," (map lib.getName watch);

      # 12h between checks, whatever the timer does. WSL boots often enough
      # that without this every terminal would pay for a nixpkgs fetch and a
      # full eval.
      MIN_INTERVAL = 12 * 3600;
      # A failed attempt (no network, usually) should come back sooner.
      RETRY_INTERVAL = 1 * 3600;
    };
  };

  notice = script.application {
    name = "sysupdate-notice";
    file = ./notice.sh;
    runtimeInputs = [ pkgs.coreutils ];
    vars.STATE_DIR = stateDir;
  };

  sysupdate = script.application {
    name = "sysupdate";
    file = ./sysupdate.sh;
    runtimeInputs = with pkgs; [
      coreutils git nix jq gnused nvd vulnix nixos-rebuild python notice
    ];
    inline = {
      HELPERS = ./helpers.sh;
      PARTS = ./sysupdate.d;
    };
    vars = shared // {
      IS_WSL = if isWsl then "1" else "";
    };
  };

in
{
  inherit sysupdate check notice stateDir;
}
