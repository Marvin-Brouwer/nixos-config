# Compact

Nothing on this machine shrinks on its own. Every rebuild leaves a system
generation behind, every `nix shell` leaves store paths, Docker keeps every
layer it pulled, and mise keeps every runtime version a repo ever asked for.
In WSL the distro also lives in a `.vhdx` that grows and never shrinks unless
it's sparse and the freed blocks are trimmed.

```bash
rig compact          # show what would go, ask, remove it, report what came back
rig compact --yes    # the same without asking
rig compact --check  # measure now and print the notice, removing nothing
rig compact --status # reprint the cached notice
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
happen. The freed blocks need to be discarded, which `rig compact` does at the
end with `fstrim`. And the disk needs to be sparse, so Windows actually hands
the discarded blocks back. That's set once, from Windows:

```powershell
wsl --shutdown
wsl --manage NixOS --set-sparse true
```

Use the distro name from `wsl -l`. The command prints the hint every run in
WSL, because whether the disk is sparse can't be seen from inside it.

## The notice

A timer measures what a run would free and caches the answer, the same way
the [sysupdate](sysupdate.md) check does. Every new shell prints it:

```txt
This machine could use a clean-up:
 - 7.2GiB of unused store paths
 - 12 system generations older than 14 days

 run rig compact to reclaim it
```

It shows when either of these is true:

- 5 GiB or more of store paths nothing uses
- 10 or more system generations older than 14 days

It stays quiet while sysupdate has something to say. That gives you one nag
per shell, and the update comes first, since applying it adds another
generation to clean up anyway.

The check runs as `compact-check.service`, 10 minutes after boot and daily
after that, at idle priority because listing dead store paths walks the whole
store. A stamp file in `/var/lib/compact` limits it to once a day, because
timer state doesn't survive a WSL shutdown. `rig compact` clears the notice
after a run.
