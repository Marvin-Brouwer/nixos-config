# -----------------------------------------------------------------
# A Claude Code skill that knows this machine: what the `rig` commands are,
# when to use which, and where the docs live. Installed as a user skill by
# configuration.nix, so every Claude Code session on this box has it.
#
# SKILL.md is the hand-written part. The command list and the list of docs
# are appended from the same data as `rig --help` and the docs/ directory,
# so adding a command or a doc page updates the skill with no edit here.
# -----------------------------------------------------------------

{ pkgs, lib, prefix, commands, docs }:

let
  # A list rather than a table: usage lines hold |, which splits a table cell
  # even inside backticks.
  entry = name: let c = commands.${name}; in
    "- `${prefix} ${name}`: ${c.summary}. Usage: `${prefix} ${c.usage}`\n";

  commandList = ''

    ## Commands

  '' + lib.concatMapStrings entry (lib.attrNames commands);

  # Every .md under docs/, one level of subdirectories deep, as paths in the
  # checkout, which is where Claude reads them.
  docPaths = lib.concatLists (lib.mapAttrsToList (name: type:
    if type == "directory"
    then map (sub: "${name}/${sub}")
      (lib.attrNames (lib.filterAttrs (n: _: lib.hasSuffix ".md" n) (builtins.readDir (docs + "/${name}"))))
    else lib.optional (lib.hasSuffix ".md" name) name
  ) (builtins.readDir docs));

  docList = ''

    ## Docs

  '' + lib.concatMapStrings (path: "- `/etc/nixos/docs/${path}`\n") docPaths;
in
pkgs.writeTextFile {
  name = "claude-skill-${prefix}";
  destination = "/SKILL.md";
  text = builtins.readFile ./SKILL.md + commandList + docList;
}
