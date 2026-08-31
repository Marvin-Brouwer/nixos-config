# My local NixOs setup

I am running NixOs in WSL, and I want per-project tool versions so I can work on
different projects without clashes. For example, I just want to run `python`,
whether the project needs 2 or 3.

NixOS provides the machine. [mise](https://mise.jdx.dev/) provides the tools, per
project, because nixpkgs only carries the runtime majors it packages and arbitrary
versions are the one thing it cannot give you.

> [!NOTE]
> The `repoconfig` command and the `docs/examples/` walkthroughs are not written
> yet, see [issue #15](https://github.com/Marvin-Brouwer/nixos-config/issues/15).

## Structure

```txt
~/
├─ .config/
│   └─ nix/
│       └─ nix.conf               # enable flakes, etcetera, here
├─ nixos-config/
│   ├─ flake.nix                    # the entry point for the whole repo
│   ├─ configuration.nix            # full NixOS system config (WSL-2 VM)
│   ├─ lib/
│   │   └─ nix-ld-libs.nix          # libraries that let vendor binaries run
│   ├─ programs/
│   │   ├─ mise.toml                # installed to /etc/mise/config.toml
│   │   ├─ vscode.nix               # the plugin sync command
│   │   └─ vscode-plugins.nix       # my base plugin list
│   └─ tools/
│       └─ playwright.nix           # FHS fallback sandbox
└─ repos/
    ├─ my-first-proj/
    │   ├─ mise.toml                # this project's tools
    │   ├─ mise.lock                # the exact versions, committed
    │   └─ .vscode/
    │       └─ extensions.json      # this project's plugins
    └─ another-proj/
        └─ ...
```

## Setup NixOS

Clone this repo

```bash
# Install git temporarily (not in base install)
nix-shell -p git
# Clone your config
git clone https://github.com/Marvin-Brouwer/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

Run the setup:

```bash
# Recursively reset ownership of the entire .git tree to the current user
sudo chown -R nixos:users .git
# Run the script
bash ./setup.sh
```

The script will:

- Enable flakes in `~/.config/nix/nix.conf`
- Symlink `/etc/nixos` to this repo so `nixos-rebuild` finds the flake
- Rebuild the WSL-2 NixOS system (`nixosConfigurations.nix-wsl`), which installs
  mise, nix-ld and the helper commands
- Add `mise.local.toml` to your global gitignore
- Install the VSCode WSL Remote extension on the Windows side

After the script finishes, restart the WSL VM so the new system takes effect.  
Exit WSL and reboot it from the windows terminal (`gitbash`/`cmd`,`pwsh`, shouldn't matter):

```bash
wsl --shutdown
wsl
```

## Setting up a project

Tools come from a `mise.toml` in the project itself, so a repo pinned to an old
node does not fight anything else on the box.

```bash
cd ~/repos/my-project
repoconfig me@example.com   # git identity, mise.toml and mise.lock, trust, local ignores
mise use node@lts           # records the tool, and its resolved version in mise.lock
```

Both files are meant to be committed. `mise.toml` is the spec and can float
(`node = "lts"`), `mise.lock` records the exact version every machine installs, and
`mise up` bumps it when you decide to.

> [!IMPORTANT]
> mise never creates `mise.lock` on its own, it only maintains one that already
> exists, and it says nothing when there is none. A repo without the file silently
> gets no version pinning at all. That is what `repoconfig` creating it is for; by
> hand it is `touch mise.lock && mise install`.

A contributor who does not use mise is not blocked by any of this: point them at
the standard file for their stack instead, `.nvmrc` or `packageManager` in
package.json for node, `global.json` for .NET.

## VSCode plugins

Two lists get unioned on entering a project:

- `programs/vscode-plugins.nix` in this repo, the ones I want everywhere.
- `<project>/.vscode/extensions.json`, the project's own. This is the standard
  file VSCode already prompts contributors to install, so it is useful to people
  who never touch this setup.

Anything in that file's `unwantedRecommendations` is removed again. The result is
installed into a VSCode profile named after the repo directory, on both the Windows
and WSL sides.

The mise hook runs it as `vscode-sync --detach` so entering a directory never
waits on the network. Run by hand it stays in the foreground, so `vscode-sync`
forces a re-check and you watch it finish. To wait on one the hook started:

```bash
vscode-sync --wait
```

> [!IMPORTANT]
> The installed set is made to equal the desired set exactly, so anything not in
> either list gets uninstalled, including extensions VSCode ships with. The base
> list therefore has to carry infrastructure as well as preferences, which is why
> `ms-vscode-remote.remote-wsl` is in it. Without that entry the sync builds
> profiles that cannot open a WSL folder at all.

> [!NOTE]
> The sync only fires inside a trusted mise project, so a repo needs a `mise.toml`
> and one `mise trust` before it works.