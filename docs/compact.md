# Compact

Nothing on this machine shrinks on its own. Every rebuild leaves a system
generation behind, every `nix shell` leaves store paths, Docker keeps every
layer it pulled, and mise keeps every runtime version a repo ever asked for.
In WSL the distro also lives in a `.vhdx` that grows and never shrinks unless
it's sparse and the freed blocks are trimmed.

```bash
rig sys compact          # show what would go, ask, remove it, report what came back
rig sys compact --yes    # the same without asking
rig sys compact --check  # measure now and print the notice, removing nothing
rig sys compact --status # reprint the cached notice
```

## What it removes

| what | how | kept |
| --- | --- | --- |
| system generations | `nix-collect-garbage --delete-older-than 14d` | the current one, and anything younger than 14 days |
| unused store paths | the same collection | anything a kept generation or a GC root uses |
| your own profile's generations | `nix-env --delete-generations 14d` | the same 14 days |
| Docker | `docker system prune` | tagged images, volumes |
| mise | `mise prune` | every version a tracked project's config still asks for |

Docker is pruned only when its daemon is already running. Asking it anything
would start it, and a daemon that isn't running has nothing new to prune.
`docker system prune -a` by hand also removes tagged images you aren't using.

14 days is `keepDays` in `programs/compact/default.nix`. Deleting a generation
means you can't roll back to it, so the run asks first and says how many.

## Getting the space back to Windows

Freeing blocks inside ext4 doesn't shrink the `.vhdx`. Two things have to
happen. The freed blocks need to be discarded, which `rig sys compact` does at the
end with `fstrim`. And the disk needs to be sparse, so Windows actually hands
the discarded blocks back. That's set once, from Windows:

```powershell
wsl --shutdown
wsl --manage NixOS --set-sparse true
```

Use the distro name from `wsl -l`. `setup.sh` prints this after installing,
and `sparseVhd=true` under `[experimental]` in `%UserProfile%\.wslconfig`
makes new distros sparse from the start; see the Readme's Install section. You don't have to remember whether you did
this: nothing inside the distro can see the flag, so `rig sys compact` asks Windows
(PowerShell through interop reads the distro's `.vhdx` location from the `Lxss`
registry key and checks the file's sparse attribute, no admin needed). It only
prints the commands above when the answer is no, or when it got no answer.
`rig sys doctor` asks the same question and warns when the disk isn't sparse.

The timer doesn't ask: a systemd unit has no WSL session, so it doesn't know
which distro it is in.

## The notice

A timer measures what a run would free and caches the answer, the same way
the [sysupdate](sysupdate.md) check does. Every new shell prints it:

```txt
This machine could use a clean-up:
 - 7.2GiB of unused store paths
 - 12 system generations older than 14 days

 run `rig sys compact --yes` to reclaim it
```

It shows when either of these is true:

- 5 GiB or more of store paths nothing uses
- 10 or more system generations older than 14 days

It only shows when there is no sysupdate to run: while sysupdate's notice has
a pending or staged update to show, this one stays quiet. That gives you one nag
per shell, and the update comes first, since applying it adds another
generation to clean up anyway.

The check runs as `compact-check.service`, 10 minutes after boot and daily
after that, at idle priority because listing dead store paths walks the whole
store. A stamp file in `/var/lib/compact` limits it to once a day, because
timer state doesn't survive a WSL shutdown. `rig sys compact` clears the notice
after a run.
