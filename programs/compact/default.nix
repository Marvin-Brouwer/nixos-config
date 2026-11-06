# -----------------------------------------------------------------
# `compact` -- give back the disk space this machine piles up, plus the
# background check and the shell notice that say when it is worth doing.
#
# Nothing on a Nix box shrinks on its own. Every rebuild leaves a system
# generation behind, every `nix shell` leaves store paths, Docker keeps every
# layer it ever pulled and mise keeps every runtime version a repo once asked
# for. In WSL it is worse: the distro lives in a .vhdx that grows and never
# shrinks unless it is sparse and the freed blocks are trimmed.
#
# Three commands come out of this directory, the same shape as sysupdate:
#
#   compact         compact.sh  show what would go, ask, prune, trim, report
#                   (its steps are compact.d/, sourced in order)
#   compact-check   check.sh    the background job, run by a systemd timer
#   compact-notice  notice.sh   prints the cached result on shell start, but
#                               only when sysupdate has nothing to say
#
# helpers.sh is what the first two share: measuring what a run would free.
# See docs/compact.md.
# -----------------------------------------------------------------

{ pkgs, lib, isWsl, prefix, sysupdateStateDir }:

let
  script = import ../../lib/shell-script.nix { inherit pkgs lib; };

  # Owned by the main user, world-readable: the check writes it, every shell
  # reads it, and `compact` clears it after a run.
  stateDir = "/var/lib/compact";

  # System generations younger than this survive a run, so there is always
  # something recent to roll back to.
  keepDays = 14;

  shared = {
    STATE_DIR = stateDir;
    KEEP_DAYS = keepDays;
    PREFIX = prefix;
  };

  check = script.application {
    name = "compact-check";
    file = ./check.sh;
    runtimeInputs = with pkgs; [ coreutils nix gawk ];
    inline.HELPERS = ./helpers.sh;
    vars = shared // {
      # Either one is enough to say something. 5 GiB of dead store paths is a
      # few nixpkgs bumps' worth; ten old generations is a month of updates.
      DEAD_THRESHOLD = 5 * 1024 * 1024 * 1024;
      GENERATIONS_THRESHOLD = 10;
      # Once a day is plenty: garbage builds up over weeks, not hours.
      MIN_INTERVAL = 24 * 3600;
    };
  };

  notice = script.application {
    name = "compact-notice";
    file = ./notice.sh;
    runtimeInputs = [ pkgs.coreutils ];
    vars = {
      STATE_DIR = stateDir;
      SYSUPDATE_STATE_DIR = sysupdateStateDir;
    };
  };

  compact = script.application {
    name = "compact";
    file = ./compact.sh;
    # docker and mise are looked up rather than listed: they come from the
    # system, and a step whose tool is missing is skipped instead of failing.
    runtimeInputs = with pkgs; [ coreutils nix gawk gnugrep util-linux systemd check notice ];
    inline = {
      HELPERS = ./helpers.sh;
      PARTS = ./compact.d;
    };
    vars = shared // {
      IS_WSL = if isWsl then "1" else "";
    };
  };
in
{
  inherit compact check notice stateDir;
}
