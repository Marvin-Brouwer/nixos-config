---
name: rig
description: Use on this NixOS-WSL dev machine whenever a task touches the machine itself rather than one project, such as setting up a repo, system updates, disk space, health checks, VSCode plugins, Docker, mise tool versions, or nixos-config. Lists the rig commands and where their docs are.
---

# This machine and its `rig` commands

This is a NixOS dev box in WSL, configured by the nixos-config repo.
`/etc/nixos` is a symlink to that checkout, usually `~/nixos-config`.

- **The machine** (git, Docker, browsers, the helper commands) comes from
  NixOS. Change it in the repo, never with `nix-env -i` or `nix profile install`.
- **Project tools** (node, pnpm, dotnet and so on) come from mise, per repo:
  the repo's `mise.toml` and the committed `mise.lock`. Don't install runtimes
  system-wide, and don't add them to the NixOS config.

Every command this setup adds lives under one prefix, `rig`. It is the only
one on PATH, so `repoconfig`, `sysupdate` and the rest are not commands on
their own. The commands are grouped: `rig sys ...` for the machine, `rig repo
...` for the repo you are in, `rig config ...` for nixos-config itself and
`rig tool ...` for helpers. `rig --help` lists the groups, `rig <group> --help`
what is in one, and `rig <group> <command> --help` is each command's own help
page. Both are generated from the same list as the one below, so
trust them if anything here looks out of date.

## Before running one

- `rig sys update` and `rig sys compact` change the system and ask questions.
  Run them only when the user asks you to, and pass the answers on.
  `rig sys compact --yes` skips its question. It deletes system generations older than 14 days,
  which means you can't roll back to them.
- `rig config build` and `rig config update` switch the running system, and
  `update` also checks out `main`. Run them only when the user asks. To check
  that a change to the config builds without switching, use
  `nix build /etc/nixos#nixosConfigurations.nix-wsl.config.system.build.toplevel --no-link`.
- `rig tool docker stop` stops every running container with the daemon. Ask
  first. `rig tool docker status` is read-only.
- `rig repo scratch` opens an interactive shell, so don't run it from an agent.
- `rig sys doctor`, `rig sys compact --check` and `rig sys update --status` are
  read-only. They're the safe first step when something about the machine
  seems wrong.
- Use `rig sys compact`, not `nix-collect-garbage` by hand, and `rig sys update`,
  not `nix flake update` plus `nixos-rebuild`. The commands also commit the
  lock, refresh the shell notices and trim the disk.
- To set up a freshly cloned repo, use `rig repo init <preset> <email>`. Add
  `--sandbox` for a repo nobody has vetted: someone else's project, or a
  take-home assignment.
- Messages put any command they want you to run in backticks.

## Where things are

- `/etc/nixos/Readme.md`: the overview, start here
- `/etc/nixos/configuration.nix`: the system, and the `rig` command list
- `/etc/nixos/programs/<command>/`: each command's source, with a
  `default.nix` header saying why it exists
