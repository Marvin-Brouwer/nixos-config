# sysupdate

One command to see what a system update would change, and apply it.

```bash
sysupdate
```

Plus a notice on every interactive shell, so you find out without asking:

```txt
You have pending system updates!
 - curl       8.9.1  -> 8.11.0   (pending 34 days)
 - git        2.45.1 -> 2.47.0
 - jq         1.7.1  -> 1.8.0
 - librewolf  141.0  -> 142.0
 - gh         2.62.0 -> 2.65.0
   ...
 + 143 other packages in the system closure
 + nixos-wsl module: d57af92 -> 9e8d7c6

 run sysupdate to update
```

The package name turns red once an update has been pending for two weeks. The
notice repeats on every new shell until you deal with it, which is the point:
this box lives in WSL and is easy to forget.

## What it does

```txt
sysupdate            update the inputs, build, show the diff, apply or stage
sysupdate --status   reprint the cached notice
sysupdate --check    run the background check now
sysupdate --audit    scan the running system for known vulnerabilities
```

The main flow, in order:

1. resolves what each flake input would move to
2. asks which ones to bump -- `nixpkgs` and `nixos-wsl` are offered separately
3. writes `flake.lock` and builds the new system, without touching the running one
4. shows `nvd diff /run/current-system <new>`, exact old to new versions
5. asks: apply now, stage for next start, or discard
6. commits the `flake.lock` bump

Apply is `nixos-rebuild switch`. Stage is `nixos-rebuild boot`, which takes
effect after `wsl --shutdown` from Windows; until then the notice says so
rather than nagging about updates you have already dealt with. Discard puts
`flake.lock` back exactly where it was.

Committing is the point of step 6: it is what keeps the machine reproducible,
and pushing is what carries the same bump to another machine. `sysupdate` does
not push -- that stays your call.

## Why it is a command, and not a timer that just does it

`system.autoUpgrade` activates silently. Seeing what changed, and choosing when
to take it, is the entire reason this exists.

In WSL it also cannot work. The VM idle-terminates once no process is a child
of its own init, so a timer set for 04:00 basically never fires. Setting
`persistent = true` catches up on the missed run, which means a multi-minute
rebuild starts exactly when you sit down to work. Wrong trade.

On a bare-metal host autoUpgrade is worth having, for the other half of the
problem: pointed at the pushed repo it activates whatever `flake.lock` you
committed. It deploys a decision rather than making one, so it never needs the
deprecated `--update-input` flag that flake-based autoUpgrade has a history of
leaning on ([NixOS/nixpkgs#349734](https://github.com/NixOS/nixpkgs/issues/349734)).
That is a change for the day a second machine exists, not before.

> [!NOTE]
> There is no meaningful reboot in WSL. NixOS does not supply the kernel,
> Microsoft does, so kernel updates do not apply and `allowReboot` is the wrong
> option. `nixos-rebuild switch` activates in place and covers nearly
> everything. Off WSL that is not true, so `sysupdate` compares the booted
> kernel with the activated one and tells you when a reboot is still needed.

## Why the check has to be a background job

Nix has no package index to diff against the way `apt` does. The only way to
know what would change is to evaluate the configuration against newer inputs,
which takes minutes and wants the network. That cannot happen between you and
your prompt, so it happens on a timer and the shell prints the cached result.

The unit is `sysupdate-check.service`, on a timer that fires two minutes after
boot and every twelve hours after that. Boot is a frequent event here, roughly
daily, which makes it a good trigger. The real rate limit is a stamp file in
`/var/lib/sysupdate`, not the timer: timer state does not survive a WSL
shutdown, so without it every terminal would pay for a nixpkgs fetch and a full
eval.

What it actually does:

- computes an updated lock with `--output-lock-file`, so it can look at the
  newest inputs while leaving `flake.lock` untouched. Only `sysupdate` writes
  the lock.
- instantiates the new system and reads its *derivation* closure. A `.drv` is
  enough to know a package's version, so nothing is downloaded or built.
- compares that against the running system's closure and renders the notice.

A failed run (no network, usually) keeps the previous answer and retries in an
hour, so the first shell after boot shows the last known state rather than
nothing.

It runs as the user who owns the repo rather than as root. It only reads the
flake and writes its own state directory, and git refuses to touch a work tree
owned by somebody else, which is exactly what a root-run check would hit.

> [!NOTE]
> Only version changes are reported. The candidate side is a build-time closure
> and the running side a runtime one, so a name that appears on one side only --
> a package added, one dropped, a compiler that is only ever a build
> dependency -- has nothing to compare against and is left out. The full
> picture is the `nvd diff` that `sysupdate` shows you.

## Why there is no per-package update

There is no such thing in Nix. The list in the notice is informational; the
action is always the whole closure. That is also why the notice names only the
handful of packages [configuration.nix](../configuration.nix) asks for by name
and counts the rest -- a full closure diff after a month of nixpkgs is a couple
of hundred lines, and none of them are individually actionable.

## vulnix

`sysupdate --audit` runs `vulnix --system`, which scans the system closure
against NVD. It answers whether being behind actually matters this time, rather
than only how long it has been.

Expect false positives. It matches on name and version, and NixOS backports
fixes without always bumping the version string. Treat it as a prompt to look,
not a verdict.

## State

Everything lives in `/var/lib/sysupdate`, world-readable so any shell can print
the notice:

| file | what it is |
| --- | --- |
| `state.json` | the diff, plus `first_seen` per package so staleness survives runs |
| `status.txt` | the rendered notice, no escape codes |
| `status.ansi` | the same notice, coloured |
| `last-attempt` | the rate-limit stamp |
| `last-failed` | present when the last run failed, which shortens the retry |
| `staged` | the system `nixos-rebuild boot` staged, cleared once it is running |

No `status.txt` means nothing is pending. That is what makes the shell notice a
file test and a `cat`: no eval, no network, nothing slow before your prompt.
