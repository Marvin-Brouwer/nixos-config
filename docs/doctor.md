# Doctor

One command for "something is off":

```bash
rig doctor
```

It checks each piece this setup depends on and prints `ok`, `warn` or `FAIL`,
with the command that fixes or explains anything that isn't ok. Commands in
hints are in backticks and coloured, like every other message in this setup
that tells you to run something. It changes
nothing and starts nothing, so it's always safe to run. It exits 1 when
something failed.

```txt
== Tools
   ok    nix-ld is active
   ok    git-lfs filters are registered
   FAIL  mise.toml is not trusted, so mise ignores it
         `mise trust`, after reading it
```

The failures this machine has are rarely loud. Without nix-ld, node fails to
start with a "No such file or directory" for a file that's plainly there. A
sysupdate timer that stopped firing just means no notice, which looks exactly
like having nothing to update. So doctor asks each piece directly, instead of
waiting for a symptom.

## What it checks

**System**

- the running system is the newest built one, not a staged update waiting for
  a restart
- no failed systemd units
- disk use, warning at 80% and failing at 90%, with `rig compact` as the fix
- the sysupdate and compact checks ran in the last three days, and the last
  update check didn't fail

**WSL** (only in WSL)

- `/mnt/c` is mounted
- Windows binaries are on PATH and actually run. Without interop, `code .` and
  the Windows half of `vscode-sync` fail with errors that don't mention it.
- `code` is reachable
- the virtual disk is sparse, so space `rig compact` frees goes back to Windows
  (see [compact](compact.md))

**Tools**

- nix-ld is active in this shell
- the git-lfs filters are registered in the system gitconfig
- mise is on PATH and `mise doctor` is happy
- gpg is there, since mise only warns and skips node's signature check
  without it
- the Docker socket listens, and the daemon answers if it's already running.
  It isn't started just to ask.
- you're in the `docker` group
- cache.nixos.org is reachable

**This repo** (only inside a git repo)

- it's set up, meaning it has a `mise.toml`
- a local git identity is set
- `mise.toml` is trusted
- `mise.lock` exists
- every tool in the config is installed

A repo set up with `--sandbox` stops after the first check. Asking mise about
it would read its config on the host, which is what the
[sandbox](sandbox.md) exists to prevent.

## Adding a check

The checks are in `programs/doctor/doctor.d/`, one file per area. A check is a
function that calls `ok`, `warn` or `fail` with a line and an optional hint.
Then `main` in `doctor.sh` calls it under its section.
