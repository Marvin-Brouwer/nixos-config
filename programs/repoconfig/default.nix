# -----------------------------------------------------------------
# `repoconfig <preset> <email>` -- set a repo up for this machine.
#
# Everything here fails silently if skipped, which is why it is one command
# rather than a list in the Readme:
#
#   * mise will not load a config it has not been told to trust, so nothing
#     downstream of that works until it is trusted.
#   * mise never creates a lockfile. It only maintains one that already
#     exists, and says nothing when there is none, so a repo without it
#     silently gets no version pinning at all.
#   * `mise install` records versions; `mise lock` is what adds the checksums
#     and URLs that make the file worth committing.
#   * vscode-sync uses the presence of mise.toml to decide a directory is a
#     managed repo, so without one a project gets no plugin sync either.
#
# Presets differ in what goes into mise.toml and .vscode/extensions.json, plus
# a Directory.Build.props for dotnet.
#
# The parts:
#
#   presets.nix       the presets, as data
#   presets/          their mise.toml bodies and extra files, verbatim
#   sandbox.nix       --sandbox: devcontainer.json and the attach check
#   check-sandbox.sh  that attach check
#   repoconfig.sh     the command
#   help.txt          its --help
#   hint.sh           the prompt hook
#
# The scripts are plain shell with @name@ placeholders for store paths and the
# values below; lib/script.nix fills them in. shellcheck them from the repo root
# with `mise run lint`.
#
# Two outputs, wired up in configuration.nix:
#
#   repoconfig   the command
#   shellInit    a prompt hook that names the command when you enter a git
#                repo it has not been run in, because that is exactly the
#                moment the name is needed and the moment it is forgotten
# -----------------------------------------------------------------

{ pkgs, lib, prefix, vscodeSync }:

let
  script = import ../../lib/script.nix { inherit lib; };
  preset = import ./presets.nix;
  sandbox = import ./sandbox.nix { inherit pkgs; };

  gitUserName = "Marvin Brouwer";

  presets = lib.attrNames preset.descriptions;

  # One store directory per preset, which repoconfig.sh looks up by name:
  #
  #   <name>/mise.toml
  #   <name>/extensions.json
  #   <name>/devcontainer.json
  #   <name>/files/...         anything else the preset writes
  presetDir = name:
    let exts = preset.recommendations.${name};
    in {
      "${name}/mise.toml" = pkgs.writeText "mise-${name}.toml"
        (builtins.readFile ./presets/header.toml + builtins.readFile ./presets/${name}.toml);
      "${name}/extensions.json" = pkgs.writeText "extensions-${name}.json" (builtins.toJSON {
        recommendations = exts;
        unwantedRecommendations = [ ];
      });
      "${name}/devcontainer.json" = sandbox.devcontainerJson name exts;
    }
    // lib.mapAttrs' (path: src: lib.nameValuePair "${name}/files/${path}" src)
      (preset.files.${name} or { });

  presetsDir = pkgs.linkFarm "repoconfig-presets"
    (lib.foldl' (acc: name: acc // presetDir name) { } presets);

  # Plain text, shared by the command and the prompt hook below so the two
  # cannot drift apart.
  usage = "usage: ${prefix} repoconfig <${lib.concatStringsSep "|" presets}> <email> [--sandbox]";

  # lib.fixedWidthString pads on the left, which right-aligns the names.
  list = pkgs.writeText "repoconfig-list.txt" ("Presets:\n\n"
    + lib.concatMapStrings (name:
        let pad = lib.concatStrings (lib.genList (_: " ") (8 - lib.stringLength name));
        in "  ${name}${pad}${preset.descriptions.${name}}\n") presets
    + "\n");

  help = pkgs.writeText "repoconfig-help.txt" (script ./help.txt { inherit usage prefix; });

  repoconfig = pkgs.writeShellScriptBin "repoconfig" (script ./repoconfig.sh {
    inherit help list usage prefix gitUserName vscodeSync;
    inherit (pkgs) coreutils git jq gnugrep;
    presets = presetsDir;
    presetNames = lib.concatStringsSep " " presets;
    sandboxCheck = sandbox.check;
  });

  # Runs before every prompt, so the common case has to cost nothing: an
  # unchanged $PWD returns on a string compare, and only a directory change
  # pays for one `git rev-parse`.
  #
  # A prompt hook rather than a git hook. git has no post-clone hook, and the
  # template-dir post-checkout trick copies a hook into every repo you clone,
  # fires for tools cloning behind your back, and still says nothing about a
  # repo cloned before it existed. Entering the repo is also when you would
  # actually run the command, which right after `git clone` you are not yet.
  #
  # Once per visit: it stays quiet while you move around inside one repo, and
  # says it again after you leave and come back. To silence it for a repo you
  # do not want set up: `git config --local repoconfig.skip true`.
  #
  # The wrapper hands back the exit status it was called with, so a prompt that
  # shows the last command's status still shows yours rather than this hook's.
  shellInit = script ./hint.sh {
    inherit prefix;
    inherit (pkgs) git;
    command = lib.removePrefix "usage: " usage;
  };
in
{
  inherit repoconfig shellInit presets;
}
