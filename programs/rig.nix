# -----------------------------------------------------------------
# `rig` (the name is devPrefix in configuration.nix) -- one prefix for every command this setup adds.
#
# They are few and used rarely, which is exactly the combination that makes
# their names hard to remember. So there is one name to remember instead:
#
#   rig --help                  what there is
#   rig <command> [args...]     runs it, args passed through untouched
#   rig <command> --help        that command's own help page
#
# The commands stay on PATH under their own names as well. `rig` only execs
# them, so nothing that calls `sysupdate` directly (the shell notice, muscle
# memory) has to change.
#
# Each entry is the package, a usage line and one sentence on when to reach for
# it. `help` is for a command that has no --help of its own; `rig` prints it
# instead of passing the flag through.
# -----------------------------------------------------------------

{ pkgs, lib, prefix, commands }:

let
  names = lib.attrNames commands;
  width = lib.foldl' (n: name: lib.max n (lib.stringLength name)) 0 names + 2;

  # lib.fixedWidthString pads on the left, which right-aligns a column of names.
  padRight = w: str: str + lib.concatStrings (lib.genList (_: " ") (w - lib.stringLength str));

  listing = lib.concatMapStrings (name: let c = commands.${name}; in
    "  ${padRight width name}${c.summary}\n"
    + "  ${padRight width ""}${prefix} ${c.usage}\n\n") names;

  overview = ''
    usage: ${prefix} <command> [args...]
           ${prefix} <command> --help

    Commands from nixos-config:

  '' + listing + ''
    Details: ~/nixos-config/Readme.md
  '';

  bin = name: "${commands.${name}.package}/bin/${commands.${name}.bin or name}";

  package = pkgs.writeShellScriptBin prefix ''
    set -uo pipefail

    overview() {
      ${pkgs.coreutils}/bin/cat <<'HELP'
    ${overview}HELP
    }

    case "''${1:-}" in
      ""|-h|--help|help) overview; exit 0 ;;
    ${lib.concatMapStrings (name: let c = commands.${name}; in ''
      ${name})
        shift
        ${lib.optionalString (c ? help) ''
        case "''${1:-}" in
          -h|--help)
            ${pkgs.coreutils}/bin/cat <<'HELP'
        ${c.help}HELP
            exit 0 ;;
        esac
        ''}exec ${bin name} "$@" ;;
    '') names}
      *)
        printf '\033[1;31m${prefix}:\033[0m unknown command: %s\n\n' "$1" >&2
        overview >&2
        exit 1 ;;
    esac
  '';

  # Tab completion: command names after the prefix, then whatever each entry offers
  # for its first argument (repoconfig's presets, for instance).
  completion = ''
    __rig_complete() {
      local cur=''${COMP_WORDS[COMP_CWORD]}
      if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "--help ${lib.concatStringsSep " " names}" -- "$cur"))
        return
      fi
      [ "$COMP_CWORD" -eq 2 ] || return
      case "''${COMP_WORDS[1]}" in
    ${lib.concatMapStrings (name: ''
        ${name}) COMPREPLY=($(compgen -W "--help ${lib.concatStringsSep " " (commands.${name}.complete or [ ])}" -- "$cur")) ;;
    '') names}
      esac
    }
    complete -F __rig_complete ${prefix}
  '';
in
{
  inherit package completion;
}
