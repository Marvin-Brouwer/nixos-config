# repoconfig

One command to set a repo up for this machine.

```bash
cd ~/repos/my-project
rig repoconfig ts me@example.com
```

The preset is `empty`, `ts` or `dotnet`, and decides what goes into `mise.toml`
and `.vscode/extensions.json`, plus a `Directory.Build.props` for `dotnet`.

Entering a git repo without a `mise.toml` prints the command, so the name does
not have to be remembered. It is a bash prompt hook rather than a git hook: git
has no post-clone hook, and the template-dir `post-checkout` workaround copies a
hook into every clone and still misses repos cloned before it. It fires once per
visit, and `git config --local repoconfig.skip true` silences it for a repo.
`rig repoconfig --list` shows the presets, `rig --help` every command this setup adds.

## What it does

Local work first, network last, so an interrupted run still leaves a usable repo.

1. sets `user.name` and `user.email` on the repo
2. writes `mise.toml` from the preset
3. runs `mise trust`
4. creates `mise.lock`
5. writes `.vscode/extensions.json` from the preset
6. writes the preset's own files (`dotnet`: `Directory.Build.props`)
7. adds `mise.local.toml` to `.git/info/exclude`
8. runs `mise install` and `mise lock --platform linux-x64,windows-x64`
9. runs `rig vscode-sync`

Nothing is overwritten. Anything already present is kept and logged, so
re-running is safe.

For a repo you don't trust, add `--sandbox`. It writes a dev container and
skips every step that would run the repo's own config on the host. See
[sandbox.md](sandbox.md).

## Why it is a command

Every step is something that fails quietly when skipped.

**`mise trust` has to come before anything reads the config.** mise will not load
a config it has not been told to trust, so `mise install` on a fresh repo does
nothing useful.

**mise never creates a lockfile.** It only maintains one that already exists, and
says nothing at all when there is none, so a repo without `mise.lock` silently
gets no version pinning. That is the exact cross-machine drift the lockfile was
chosen to prevent, failing without a word.

**`mise install` records versions, `mise lock` adds the checksums and URLs.**
The difference between everyone getting the same version and everyone getting the
same artifact.

**`mise.toml` also marks the repo as one the plugin sync manages.** A project
without one gets no VSCode plugins either.

**Ignores go in `.git/info/exclude`, not `.gitignore`.** Personal tooling should
not turn up in other people's diffs. Only `mise.local.toml` is excluded;
`mise.toml` and `mise.lock` are meant to be committed.

## The presets

| preset | mise.toml | extensions.json | other files |
| --- | --- | --- | --- |
| `empty` | no tools | empty | |
| `ts` | node, pnpm, typescript | the TypeScript set | |
| `dotnet` | dotnet | the C# set | `Directory.Build.props` with NuGet lock files ([why](examples/csharp.md#directorybuildprops)) |

Each writes a `[tasks.setup]` so a fresh clone is `mise run setup`.

The plugin lists keep their comments in `programs/repoconfig.nix` and lose them
on the way into a repo. Notes about what I might drop later are mine and have no
business in a repo other people read.

## Per-stack detail

What each generated file is for, who reads it, and what to add by hand:

- [TypeScript](examples/ts.md)
- [C#](examples/csharp.md)
