# My local NixOs setup

NixOs in WSL, with per-project tool versions so different projects do not clash.
I want to run `python` and get whichever version that project needs.

Two halves:

- **NixOS** is the machine. git, curl, browsers, the VSCode plumbing, keeping
  itself up to date, and the helper commands below, all under `rig`.
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
│   ├─ configuration.nix            # the NixOS system, and the rig command tree
│   ├─ setup.sh                     # one-time bootstrap, see Install
│   ├─ lib/
│   │   ├─ shell-script.nix         # turns the .sh files into commands
│   │   ├─ highlight.sh             # colours `commands` in messages
│   │   ├─ config-repo.sh           # where /etc/nixos points, for the commands
│   │   └─ nix-ld-libs.nix          # libraries that let vendor binaries run
│   ├─ programs/                    # one directory per command: programs/<group>/<command>
│   │   ├─ rig.nix                  # the `rig` prefix: dispatch, help, completion
│   │   ├─ mise.toml                # installed to /etc/mise/config.toml
│   │   ├─ claude-skill/            # the Claude Code skill that knows rig
│   │   ├─ sys/                     # rig sys: the machine itself
│   │   │   ├─ update/              #   updates: command, timer check, shell notice
│   │   │   ├─ compact/             #   disk clean-up: command, timer check, notice
│   │   │   └─ doctor/              #   the health check, doctor.d/ per area
│   │   ├─ repo/                    # rig repo: the repo you are in
│   │   │   ├─ init/                #   one-shot repo setup, its hint and presets/
│   │   │   └─ scratch/             #   throwaway repo with a preset
│   │   ├─ config/                  # rig config: this repo
│   │   │   ├─ build/               #   build the checked-out branch and switch
│   │   │   └─ update/              #   back to main, pull, build if changed
│   │   └─ tool/                    # rig tool: helpers for project tooling
│   │       ├─ vscode-sync/         #   the plugin sync, and plugins.nix, my base list
│   │       ├─ playwright/          #   FHS fallback sandbox for browsers
│   │       └─ docker/              #   start, stop, restart the daemon
│   ├─ docs/                        # one page per command, plus examples/
│   └─ .github/workflows/check.yml  # CI: lint, and build the whole system
└─ repos/
    └─ my-project/
        ├─ mise.toml                # this project's tools
        ├─ mise.lock                # the exact versions, committed
        └─ .vscode/extensions.json  # this project's plugins
```

Each command directory has a `default.nix` saying why it exists and what each
file is for. A long script is split into steps under `<script>.d/`, sourced in
order, with a `main` at the bottom of the script calling them by name.

The shell scripts under `programs/` are real `.sh` files. Nix gives them their
tools on PATH and their values as variables (`lib/shell-script.nix`), and
`mise run lint` shellchecks them.

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
Windows terminal so the new system takes effect, and make its disk sparse while
it's down:

```bash
wsl --shutdown
wsl --manage NixOS --set-sparse true   # the distro name from `wsl -l`
wsl
```

Without the sparse flag the `.vhdx` only ever grows: space freed inside WSL,
by `rig sys compact` for instance, stays allocated on the Windows side. It can
only be set while WSL is shut down, so `setup.sh` prints it rather than running
it, with your distro's name filled in. To have every new distro start out sparse,
put this in `%UserProfile%\.wslconfig` before importing:

```ini
[experimental]
sparseVhd=true
```

`rig sys doctor` warns if the disk isn't sparse, so you'll hear about it if
this step was skipped.

## One prefix for everything

Every command this setup adds lives under `rig`, so there is one name to
remember:

```bash
rig --help                # the groups: config, repo, sys, tool
rig repo --help           # what is in one group
rig repo init --help      # one command's own help page
rig repo init --list      # the presets
rig sys update            # see and apply system updates
rig sys compact           # free disk space, see docs/compact.md
rig sys doctor            # something is off? see docs/doctor.md
rig repo scratch ts       # a throwaway repo, see docs/scratch.md
rig config build          # build this checkout's branch and switch to it
rig config update         # back to main, pull, rebuild if anything changed
rig tool vscode-sync      # re-check this repo's VSCode plugins
rig tool playwright       # FHS sandbox for browsers
rig tool docker stop      # stop the Docker daemon to free memory; start, restart, status
```

Claude Code knows them too. The config installs a user skill at
`~/.claude/skills/rig` (`programs/claude-skill/`) listing every command and doc
page. It is generated from the same list as `rig --help`, so it can't drift.

Tab completion covers the groups, the commands in them and each command's first
argument. Only `rig` is on PATH; the commands are not installed under their own
names.
The prefix itself is `devPrefix` in `configuration.nix`.

## Setting up a project

```bash
cd ~/repos/my-project
rig repo init ts me@example.com
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
re-running is safe. What each step is for is in [docs/repoconfig.md](docs/repoconfig.md).

For a repo you don't trust, `--sandbox` sets it up as a dev container instead,
with host credentials kept out. See [docs/sandbox.md](docs/sandbox.md).

You do not have to remember the name. Entering a git repo that has no
`mise.toml` prints it:

```txt
This repo is not set up yet, run: `rig repo init <dotnet|empty|ts> <email>`
   (`rig --help` lists every command on this machine)
```

For a repo you deliberately leave alone, `git config --local repoconfig.skip true`
silences the hint there.

`mise.toml` and `mise.lock` both get committed. The first is the spec and can
float, the second records the exact version every machine installs, and `mise up`
bumps it when you decide to.

> [!IMPORTANT]
> mise never creates `mise.lock` itself. It only maintains one that already
> exists, and says nothing when there is none, so a repo without the file
> silently gets no version pinning at all. That is the main thing `rig repo init`
> is for. By hand it is `touch mise.lock && mise install && mise lock`.

> [!NOTE]
> Only `node` accepts `lts`. That is an alias the node plugin defines, not a
> mise-wide concept, so everything else takes `latest` or a version.

## Keeping the system up to date

Every interactive shell says what a system update would change, from a cached
answer a timer writes:

```txt
You have pending system updates!
 - curl       8.9.1  -> 8.11.0   (pending 34 days)
 - git        2.45.1 -> 2.47.0
 - jq         1.7.1  -> 1.8.0
   ...
 + 143 other packages in the system closure

 run `rig sys update` to update
```

```bash
rig sys update          # bump the inputs, build, show the diff, apply or stage
rig sys update --audit  # scan the running system for known vulnerabilities
```

`rig sys update` asks about `nixpkgs` and `nixos-wsl` separately, builds the new
system without touching the running one, shows `nvd diff` for the exact old to
new versions, and then asks: apply now, stage for the next start, or discard.
Applying is `nixos-rebuild switch`; staging is `nixos-rebuild boot`, which takes
effect after `wsl --shutdown`. Either way the `flake.lock` bump is committed, so
the machine stays reproducible and the same versions travel to another box.

Nothing here is `system.autoUpgrade`. It activates silently, which defeats the
purpose, and in WSL its timer never fires anyway. Why, and how the background
check works without slowing down your prompt, is in
[docs/sysupdate.md](docs/sysupdate.md).

## Changing the config

`rig config build` builds whatever branch the checkout is on and switches to it,
which is `sudo nixos-rebuild switch --flake .#nix-wsl` with a diff first and
nothing to remember. `rig config update` is the way back: it switches to
`main`, pulls it and rebuilds when that changed anything, and stops instead of
guessing when the tree is dirty or `main` has diverged. See
[docs/config.md](docs/config.md).

## Housekeeping

`rig sys compact` removes system generations older than 14 days, the store
paths nothing uses any more, Docker's leftovers and mise tool versions no project asks
for, then trims the disk so the WSL `.vhdx` can shrink. It shows what it would
remove and asks first. A daily timer measures whether a run is worth it, and
when it is, new shells say so, but only when sysupdate has nothing to say. See
[docs/compact.md](docs/compact.md).

`rig sys doctor` checks every piece this setup depends on (nix-ld, interop,
Docker, mise, the timers, the repo you're in) and says per piece whether it's
fine and what to do if not. See [docs/doctor.md](docs/doctor.md).

`rig repo scratch [preset]` makes a temp repo, runs `rig repo init` in it and
drops you in a shell there. Leaving the shell offers to delete it. See
[docs/scratch.md](docs/scratch.md).

`rig tool docker stop` stops the Docker daemon, its socket and every container,
which gives the WSL VM its memory back. The daemon is socket-activated, so the
next `docker` command starts it again; `start`, `restart` and `status` are
there too. See [docs/docker.md](docs/docker.md).

## VSCode plugins

Two lists are unioned when you enter a project:

- `programs/tool/vscode-sync/plugins.nix` here, the ones I want everywhere
- `<project>/.vscode/extensions.json`, the project's own, which is the standard
  file VSCode already prompts contributors to install

Then anything in that file's `unwantedRecommendations` is removed, and the result
is installed on both the Windows and WSL sides.

```bash
rig tool vscode-sync          # force a re-check, in the foreground
rig tool vscode-sync --wait   # wait for one the mise hook started
```

Entering a project runs the sync in the foreground, so it prints what it did and
you wait for it. Most entries hit the hash fast path and return instantly; it
only blocks when the plugin set actually changed, which with one shared set means
when you move between repos that want different plugins.

`rig tool vscode-sync --detach` is the alternative. It backgrounds the sync and
writes to `~/.config/nixos-vscode-sync/last.log` instead of printing, because a background
job writing over a prompt that has already been drawn leaves the shell looking
hung until you press enter.

> [!IMPORTANT]
> The installed set is made to equal the desired set exactly, so anything in
> neither list gets uninstalled, including extensions VSCode ships with.
> `ms-vscode-remote.remote-wsl` is the one exception. It is machine-specific
> infrastructure rather than a preference, so it is not in the base list;
> `programs/tool/vscode-sync/sync.sh` adds it when it sees a Windows side to talk to, after the
> unwanted filter, because a project vetoing it would leave an editor that cannot
> open a WSL folder.

> [!NOTE]
> There is one extension set, not one per repo, so moving between repos with
> different plugins installs and uninstalls the difference each time. VSCode
> profiles cannot be used: `code --profile <name> --install-extension` will not
> create a profile that does not exist, it reports "Profile not found" and exits
> 0 ([microsoft/vscode#176372](https://github.com/microsoft/vscode/issues/176372)).
> Creating one means opening a window, which a `cd` has no business doing.

The sync only runs inside a trusted mise project, so a repo needs a `mise.toml`
and one `mise trust` first. `rig repo init` does both.

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
