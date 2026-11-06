# -----------------------------------------------------------------
# Reads a script that lives in the repo as a real file and fills in its
# @name@ placeholders, the same syntax pkgs.replaceVars uses.
#
# The scripts are kept as files so they can be read, edited and shellchecked
# as shell rather than as a Nix string with ''${ escapes. What they cannot do
# is name a store path, so every tool is a placeholder here and an absolute
# path in the result, exactly as when the script was a Nix string.
#
# This runs at evaluation time rather than as a build step, so the result is an
# ordinary string for writeShellScriptBin and friends, with the string context
# of every store path it names.
#
# Both directions are checked, so a typo fails the evaluation instead of
# shipping a script that runs `@git@/bin/git`:
#
#   * a placeholder in the file with no value
#   * a value that no placeholder in the file asks for
# -----------------------------------------------------------------

{ lib }:

file: vars:

let
  raw = builtins.readFile file;
  names = lib.attrNames vars;

  # A path is interpolated rather than passed to toString: interpolating copies
  # it to the store and keeps the reference, where toString would hand back the
  # file's location in the checkout and let the store forget it.
  value = v: if builtins.isPath v then "${v}" else toString v;

  text = builtins.replaceStrings
    (map (name: "@${name}@") names)
    (map (name: value vars.${name}) names)
    raw;

  # builtins.split interleaves the text with a list of capture groups per match.
  leftover = lib.unique (map lib.head (lib.filter lib.isList
    (builtins.split "(@[A-Za-z_][A-Za-z0-9_]*@)" text)));
  unused = lib.filter (name: !lib.hasInfix "@${name}@" raw) names;

  where = baseNameOf (toString file);
in
if leftover != [ ] then
  throw "${where}: no value for ${lib.concatStringsSep ", " leftover}"
else if unused != [ ] then
  throw "${where}: no placeholder for ${lib.concatStringsSep ", " unused}"
else
  text
