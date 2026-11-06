# -----------------------------------------------------------------
# `devhelp` -- the commands this setup adds, in one place.
#
# They are few and used rarely, which is exactly the combination that makes
# their names hard to remember. A list by hand rather than generated: the point
# is one line on when to reach for each, which no --help scrape would give.
# Keep it in step when adding or renaming a command.
# -----------------------------------------------------------------

{ pkgs }:

pkgs.writeShellScriptBin "devhelp" ''
  ${pkgs.coreutils}/bin/cat <<'HELP'

  Commands from nixos-config:

    repoconfig <empty|ts|dotnet> <email>
        Set up the repo you are in: git identity, mise.toml, trust, lockfile,
        .vscode/extensions.json. Run once after cloning. Safe to re-run.

    sysupdate [--status|--check|--audit]
        See pending system updates and apply or stage them.

    vscode-sync [--wait|--detach]
        Sync VSCode plugins for this repo. Runs by itself on entering a repo.

    playwright-fhs
        FHS sandbox for browsers nix-ld does not cover.

  Details: ~/nixos-config/Readme.md and docs/.

HELP
''
