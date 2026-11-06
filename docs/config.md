# Config

Two commands for working on this repo itself:

```bash
rig config build   # build the checked-out branch and switch to it
rig config update  # back to main, pull it, build if that changed anything
```

`build` is for trying a branch. `update` is the way back afterwards, and the
way to pick up a change made elsewhere, such as a `flake.lock` bump
`rig sys update` pushed from another machine. For updating the flake inputs
themselves, use `rig sys update`, see [sysupdate.md](sysupdate.md).

## `rig config build`

`sudo nixos-rebuild switch --flake .#nix-wsl` without having to remember it,
plus a diff before it switches. In order:

1. Builds the checkout `/etc/nixos` points at (`~/nixos-config`), wherever
   you run it from. It says which branch and commit, and whether there are
   uncommitted changes.
2. Warns about untracked files. A flake in a git repo only sees tracked files,
   so a new `.nix` file you haven't `git add`ed is silently not there.
3. Builds the system as you, with `nix build`, outside the checkout. A failed
   build switches nothing.
4. Stops when the result is the system already running. A change to docs or
   comments ends here.
5. Shows `nvd diff` against the running system, then runs
   `sudo nixos-rebuild switch`, which re-evaluates but builds nothing new.

Uncommitted changes are built as they are, since trying a change before
committing it is the point. There's no question before the switch: you asked
for one. To go back, `rig config update`, or
`sudo nixos-rebuild switch --rollback` for the previous generation.

## `rig config update`

Always `main`, because the branch you were trying is usually merged and deleted
by now, and that's exactly where plain `git pull` fails with
`no such ref was fetched`. In order:

1. Goes to the checkout `/etc/nixos` points at and refuses to start when it has
   uncommitted changes to tracked files. Nothing is stashed for you: a
   forgotten stash on this repo is a change you think is in the system and
   isn't. Commit or stash it, or `rig config build` it as it is.
2. Fetches `origin` with `--prune`. The whole remote, not the current branch's
   upstream, so a deleted branch can't fail it.
3. Switches to `main`, making a local one that tracks `origin/main` if there
   isn't one. When the branch you left is merged into `main` and gone from the
   remote, it says so and gives the `git branch -d` to remove it. It doesn't
   delete it for you.
4. Fast-forwards `main` to `origin/main`. Up to date or ahead is fine. When
   they've diverged it stops and leaves the merge or rebase to you.
5. Stops when the commit checked out is the one it started on. Otherwise it
   lists the new commits and runs `rig config build`, which only switches when
   the system actually differs.
6. When `flake.lock` changed, clears the sysupdate notice and starts a fresh
   check in the background, since the update it announced has probably just
   arrived.

`main` and `origin` are `BRANCH` and `REMOTE` in `programs/config/default.nix`.
