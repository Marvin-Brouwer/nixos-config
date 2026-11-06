# -----------------------------------------------------------------
# The scripts under programs/ are real .sh files, so they can be read, edited
# and shellchecked as shell rather than as a Nix string full of ''${ escapes.
# This is how Nix hands them what they cannot know on their own:
#
#   * tools go on PATH through writeShellApplication's runtimeInputs, so a
#     script says `git`, not a store path
#   * values (the prefix, store paths of data files, host facts) are shell
#     variables assigned ahead of the script, unconditionally, so nothing in
#     the caller's environment can stand in for them
#
# Each script names the variables it expects with `: "${NAME:?}"` near the
# top, which documents them and stops a run that does not have them.
#
# writeShellApplication also shellchecks the assembled script at build time.
# Its own `set -o errexit ...` is turned off: each script keeps the options it
# was written for on its own `set` line, and not all of them want errexit.
# -----------------------------------------------------------------

{ pkgs, lib }:

let
  # A path is interpolated rather than passed to toString: interpolating copies
  # it to the store and keeps the reference, where toString would hand back the
  # file's location in the checkout and let the store forget it.
  value = v: if builtins.isPath v then "${v}" else toString v;
in
rec {
  # NAME='value' lines, for prepending to a script.
  assignments = vars: lib.concatStrings (lib.mapAttrsToList
    (name: v: "${name}=${lib.escapeShellArg (value v)}\n") vars);

  application = { name, file, runtimeInputs ? [ ], vars ? { }, excludeShellChecks ? [ ] }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      bashOptions = [ ];
      text = assignments vars + builtins.readFile file;
    };
}
