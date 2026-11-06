# -----------------------------------------------------------------
# `rig` -- the one entry point for every command this setup adds. The name is
# devPrefix in configuration.nix.
#
# They are few and used rarely, which is exactly the combination that makes
# their names hard to remember. So there is one name to remember instead, and
# the commands are grouped by what they act on:
#
#   rig --help                    the groups, one line each
#   rig <group> --help            what is in one
#   rig <group> <command> [args]  runs it, args passed through untouched
#   rig <group> <command> --help  that command's own help page
#
# The commands are not on PATH under their own names. `rig` execs them by
# store path, and so does anything else that calls one (the mise enter hook,
# repoconfig running the plugin sync).
#
# An entry is either a command or a group:
#
#   command  { package; summary; usage; complete?; bin?; help?; }
#   group    { summary; commands = { <name> = entry; ... }; }
#
# usage is the arguments only; the path in front of it is added here. help is
# for a command that has no --help of its own; `rig` prints it instead of
# passing the flag through. Groups nest as deep as they like, and the help
# pages and tab completion follow.
# -----------------------------------------------------------------

{ pkgs, lib, prefix, commands }:

let
  cat = "${pkgs.coreutils}/bin/cat";

  isGroup = entry: entry ? commands;

  # lib.fixedWidthString pads on the left, which right-aligns a column of names.
  padRight = w: str: str + lib.concatStrings (lib.genList (_: " ") (w - lib.stringLength str));

  # "rig sys update", from [ "sys" "update" ].
  invocation = path: lib.concatStringsSep " " ([ prefix ] ++ path);

  # The line under a summary: how to call it. A group names what is in it.
  usageLine = path: entry:
    if isGroup entry
    then "${invocation path} <${lib.concatStringsSep "|" (lib.attrNames entry.commands)}>"
    else lib.concatStringsSep " " ([ (invocation path) ] ++ lib.optional (entry.usage != "") entry.usage);

  # One help page per group: its entries, a summary and a usage line each.
  helpPage = path: group:
    let
      names = lib.attrNames group.commands;
      width = lib.foldl' (n: name: lib.max n (lib.stringLength name)) 0 names + 2;
      listing = lib.concatMapStrings (name: let e = group.commands.${name}; in
        "  ${padRight width name}${e.summary}\n"
        + "  ${padRight width ""}${usageLine (path ++ [ name ]) e}\n\n") names;
    in ''
      usage: ${invocation path} <command> [args...]
             ${invocation path} <command> --help

    '' + (if path == [ ] then "Commands from nixos-config:\n\n" else "${invocation path}: ${group.summary}\n\n")
    + listing + ''
      Details: ~/nixos-config/Readme.md
    '';

  bin = entry: "${entry.package}/bin/${entry.bin or (lib.getName entry.package)}";

  # A nested case per group. The first argument picks an entry, is shifted off,
  # and the rest goes to the next level down or to the command itself.
  dispatch = path: group: ''
    case "''${1:-}" in
      ""|-h|--help|help)
        ${cat} <<'HELP'
    ${helpPage path group}HELP
        exit 0 ;;
    ${lib.concatMapStrings (name: let e = group.commands.${name}; in ''
      ${name})
        shift
        ${if isGroup e then dispatch (path ++ [ name ]) e else command e}
        ;;
    '') (lib.attrNames group.commands)}
      *)
        printf '\033[1;31m${invocation path}:\033[0m unknown command: %s\n\n' "$1" >&2
        ${cat} >&2 <<'HELP'
    ${helpPage path group}HELP
        exit 1 ;;
    esac
  '';

  command = entry: lib.optionalString (entry ? help) ''
    case "''${1:-}" in
      -h|--help)
        ${cat} <<'HELP'
    ${entry.help}HELP
        exit 0 ;;
    esac
  '' + "exec ${bin entry} \"$@\"";

  root = { summary = "Commands from nixos-config"; inherit commands; };

  package = pkgs.writeShellScriptBin prefix ''
    set -uo pipefail
    ${dispatch [ ] root}
  '';

  # Every group and command as { path, entry }, depth first, groups included.
  walk = path: entry: [ { inherit path entry; } ] ++ lib.optionals (isGroup entry)
    (lib.concatMap (name: walk (path ++ [ name ]) entry.commands.${name}) (lib.attrNames entry.commands));
  nodes = walk [ ] root;

  # Every command, for anything else generated from the same tree, such as the
  # Claude skill in programs/claude-skill: its full invocation, summary and
  # usage line.
  leaves = map (n: {
    invocation = invocation n.path;
    usage = usageLine n.path n.entry;
    inherit (n.entry) summary;
  }) (lib.filter (n: !(isGroup n.entry)) nodes);

  # Tab completion: the words typed so far, after the prefix, pick the node.
  # A group offers its entries, a command whatever its entry lists for its
  # first argument (repoconfig's presets, for instance).
  completion = ''
    __rig_complete() {
      local cur=''${COMP_WORDS[COMP_CWORD]} words
      local path="''${COMP_WORDS[*]:1:COMP_CWORD-1}"
      case "$path" in
    ${lib.concatMapStrings (n: ''
        ${lib.escapeShellArg (lib.concatStringsSep " " n.path)}) words=${lib.escapeShellArg (lib.concatStringsSep " "
          (if isGroup n.entry then lib.attrNames n.entry.commands else n.entry.complete or [ ]))} ;;
    '') nodes}
        *) return ;;
      esac
      COMPREPLY=($(compgen -W "--help $words" -- "$cur"))
    }
    complete -F __rig_complete ${prefix}
  '';
in
{
  inherit package completion leaves;
}
