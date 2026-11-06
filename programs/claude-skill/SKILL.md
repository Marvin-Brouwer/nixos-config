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
their own. `rig --help` lists them, and `rig <command> --help` is each one's
own help page. Both are generated from the same list as the one below, so
trust them if anything here looks out of date.

## Before running one

- `rig sysupdate` and `rig compact` change the system and ask questions. Run
  them only when the user asks you to, and pass the answers on. `rig compact
  --yes` skips its question. It deletes system generations older than 14 days,
  which means you can't roll back to them.
- `rig scratch` opens an interactive shell, so don't run it from an agent.
- `rig doctor`, `rig compact --check` and `rig sysupdate --status` are
  read-only. They're the safe first step when something about the machine
  seems wrong.
- Use `rig compact`, not `nix-collect-garbage` by hand, and `rig sysupdate`,
  not `nix flake update` plus `nixos-rebuild`. The commands also commit the
  lock, refresh the shell notices and trim the disk.
- To set up a freshly cloned repo, use `rig repoconfig <preset> <email>`. Add
  `--sandbox` for a repo nobody has vetted: someone else's project, or a
  take-home assignment.
- Messages put any command they want you to run in backticks.

## Where things are

- `/etc/nixos/Readme.md`: the overview, start here
- `/etc/nixos/configuration.nix`: the system, and the `rig` command list
- `/etc/nixos/programs/<command>/`: each command's source, with a
  `default.nix` header saying why it exists
