# -----------------------------------------------------------------
# The presets: what `rig repo init <preset>` writes into a repo.
#
# One directory per preset, found by listing this one, so adding a preset is
# adding a directory:
#
#   <name>/default.nix       description, plugins, and any extra files
#   <name>/mise-preset.toml  the repo's mise.toml, after header.toml
#
# default.nix holds:
#
#   description      one line for `--list`
#   recommendations  the plugins for the repo's .vscode/extensions.json
#   files            optional; extra files by name in the repo root
#
# The plugins are the ones the *project* wants, which is not the same list as
# the ones I want everywhere. Mine live in programs/vscode-plugins.nix and never
# go into someone else's repository; these are the ones a contributor also
# benefits from, which is why they belong in the standard extensions.json.
# Their comments are kept in the .nix files and stripped on the way out: notes
# about what I might drop later are mine, and have no business in a repo other
# people read.
#
# The preset names everywhere else (usage, the lookup in repoconfig.sh, the
# prompt hint, completion) come from the directory names.
# -----------------------------------------------------------------

{ lib }:

let
  names = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.));
in
lib.genAttrs names (name: {
  files = { };
  miseToml = builtins.readFile ./header.toml + builtins.readFile ./${name}/mise-preset.toml;
} // import ./${name})
