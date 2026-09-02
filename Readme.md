# My local NixOs setup

NixOs in WSL, with per-project tool versions so different projects do not clash.
I want to run `python` and get whichever version that project needs.

Two halves:

- **NixOS** is the machine. git, curl, browsers, the VSCode plumbing, and the
  helper commands below.
- **[mise](https://mise.jdx.dev/)** is the tools. node, pnpm, dotnet, per project,
  because nixpkgs only carries the runtime majors it packages and arbitrary
  versions are the one thing it cannot give you.

A project declares what it needs in files that work for anyone who clones it,
whether or not they have mise or NixOS. See [docs/examples/ts.md](docs/examples/ts.md)
and [docs/examples/csharp.md](docs/examples/csharp.md).

## Structure

```txt
~/
├─ nixos-config/
│   ├─ flake.nix                    # entry point
│   ├─ configuration.nix            # the NixOS system
│   ├─ lib/
│   │   └─ nix-ld-libs.nix          # libraries that let vendor binaries run
│   ├─ programs/
│   │   ├─ mise.toml                # installed to /etc/mise/config.toml
│   │   ├─ repoconfig.nix           # one-shot repo setup command
│   │   ├─ vscode.nix               # the plugin sync command
│   │   └─ vscode-plugins.nix       # my base plugin list
│   ├─ tools/
│   │   └─ playwright.nix           # FHS fallback sandbox
│   └─ docs/
│       └─ examples/                # per-stack walkthroughs
└─ repos/
    └─ my-project/
        ├─ mise.toml                # this project's tools
        ├─ mise.lock                # the exact versions, committed
        └─ .vscode/extensions.json  # this project's plugins
```

## Install

```bash
nix-shell -p git
git clone https://github.com/Marvin-Brouwer/nixos-config.git ~/nixos-config
cd ~/nixos-config
sudo chown -R nixos:users .git
bash ./setup.sh
```

That enables flakes, symlinks `/etc/nixos` here, rebuilds the system, and installs
the VSCode WSL Remote extension on the Windows side. Then restart WSL from a
Windows terminal so the new system takes effect:

```bash
wsl --shutdown
wsl
```

## Setting up a project

```bash
cd ~/repos/my-project
repoconfig ts me@example.com
```

The preset is `empty`, `ts` or `dotnet`, and only decides what goes into
`mise.toml` and `.vscode/extensions.json`. Everything else is the same:

- sets the local git identity
- writes `mise.toml`, which also marks the repo as one the plugin sync manages
- runs `mise trust`, before anything reads that config
- creates and fills `mise.lock`
- writes `.vscode/extensions.json`
- adds a `setup` task, so a fresh clone is `mise run setup`
- excludes `mise.local.toml` in `.git/info/exclude` rather than the repo's
  `.gitignore`, so personal tooling stays out of other people's diffs

Nothing is overwritten. Anything already present is kept and logged, so
re-running is safe.

`mise.toml` and `mise.lock` both get committed. The first is the spec and can
float, the second records the exact version every machine installs, and `mise up`
bumps it when you decide to.

> [!IMPORTANT]
> mise never creates `mise.lock` itself. It only maintains one that already
> exists, and says nothing when there is none, so a repo without the file
> silently gets no version pinning at all. That is the main thing `repoconfig`
> is for. By hand it is `touch mise.lock && mise install && mise lock`.

> [!NOTE]
> Only `node` accepts `lts`. That is an alias the node plugin defines, not a
> mise-wide concept, so everything else takes `latest` or a version.

## VSCode plugins

Two lists are unioned when you enter a project:

- `programs/vscode-plugins.nix` here, the ones I want everywhere
- `<project>/.vscode/extensions.json`, the project's own, which is the standard
  file VSCode already prompts contributors to install

Then anything in that file's `unwantedRecommendations` is removed, and the result
is installed on both the Windows and WSL sides.

```bash
vscode-sync          # force a re-check, in the foreground
vscode-sync --wait   # wait for one the mise hook started
```

Entering a project runs the sync in the foreground, so it prints what it did and
you wait for it. Most entries hit the hash fast path and return instantly; it
only blocks when the plugin set actually changed, which with one shared set means
when you move between repos that want different plugins.

`vscode-sync --detach` is the alternative. It backgrounds the sync and writes to
`~/.config/nixos-vscode-sync/last.log` instead of printing, because a background
job writing over a prompt that has already been drawn leaves the shell looking
hung until you press enter.

> [!IMPORTANT]
> The installed set is made to equal the desired set exactly, so anything in
> neither list gets uninstalled, including extensions VSCode ships with. The base
> list therefore has to carry infrastructure as well as preferences, which is why
> `ms-vscode-remote.remote-wsl` is in it. Without that entry the sync produces an
> editor that cannot open a WSL folder.

> [!NOTE]
> There is one extension set, not one per repo, so moving between repos with
> different plugins installs and uninstalls the difference each time. VSCode
> profiles cannot be used: `code --profile <name> --install-extension` will not
> create a profile that does not exist, it reports "Profile not found" and exits
> 0 ([microsoft/vscode#176372](https://github.com/microsoft/vscode/issues/176372)).
> Creating one means opening a window, which a `cd` has no business doing.

The sync only runs inside a trusted mise project, so a repo needs a `mise.toml`
and one `mise trust` first. `repoconfig` does both.

## Why vendor binaries run at all

`programs.nix-ld` is load-bearing for the whole setup, not just browsers.
Everything mise installs is an ordinary vendor build expecting an FHS layout
NixOS does not have, so without the shim node, pnpm and the .NET SDK all install
cleanly and then fail to start.

> [!NOTE]
> `ldd` is not a valid test here. It resolves against the standard search paths,
> while nix-ld works at runtime through a loader shim reading
> `NIX_LD_LIBRARY_PATH`, so it reports every library nix-ld provides as missing
> even when the binary runs fine. Use
> `LD_LIBRARY_PATH="$NIX_LD_LIBRARY_PATH" ldd <binary>` or do not bother.
