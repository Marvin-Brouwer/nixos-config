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
# A script split into parts sources them, as `. "$PARTS/name.sh"`, with a
# `# shellcheck source=` line so `mise run lint` follows them. Nix inlines
# those lines when it builds the command (`inline` below names what each
# variable stands for), so the command is still one script, and the build's
# shellcheck sees all of it too.
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

  # Replaces each `. "$VAR"` or `. "$VAR/file"` line, for a VAR in `inline`,
  # with that file's contents. One level deep: a part does not source more.
  inlineSources = inline: text: lib.concatMapStringsSep "\n" (line:
    let m = builtins.match ''[[:space:]]*\. "\$([A-Z_]+)(/[^"]*)?"'' line;
    in if m == null || !(inline ? ${builtins.head m}) then line
    else
      let target = inline.${builtins.head m};
          path = if builtins.elemAt m 1 == null then target else target + builtins.elemAt m 1;
      in lib.removeSuffix "\n" (builtins.readFile path)
  ) (lib.splitString "\n" text);

  application = { name, file, runtimeInputs ? [ ], vars ? { }, inline ? { }, excludeShellChecks ? [ ] }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      bashOptions = [ ];
      text = assignments vars + inlineSources inline (builtins.readFile file);
    };
}
