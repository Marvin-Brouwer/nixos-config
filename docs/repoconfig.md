# repoconfig

One command to set a repo up for this machine.

```bash
cd ~/repos/my-project
repoconfig ts me@example.com
```

The preset is `empty`, `ts` or `dotnet`, and only decides what goes into
`mise.toml` and `.vscode/extensions.json`.

## What it does

Local work first, network last, so an interrupted run still leaves a usable repo.

1. sets `user.name` and `user.email` on the repo
2. writes `mise.toml` from the preset
3. runs `mise trust`
4. creates `mise.lock`
5. writes `.vscode/extensions.json` from the preset
6. adds `mise.local.toml` to `.git/info/exclude`
7. runs `mise install` and `mise lock --platform linux-x64,windows-x64`
8. runs `vscode-sync`

Nothing is overwritten. Anything already present is kept and logged, so
re-running is safe.

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

| preset | mise.toml | extensions.json |
| --- | --- | --- |
| `empty` | no tools | empty |
| `ts` | node, pnpm, typescript | the TypeScript set |
| `dotnet` | dotnet | the C# set |

Each writes a `[tasks.setup]` so a fresh clone is `mise run setup`.

The plugin lists keep their comments in `programs/repoconfig.nix` and lose them
on the way into a repo. Notes about what I might drop later are mine and have no
business in a repo other people read.

## Per-stack detail

What each generated file is for, who reads it, and what to add by hand:

- [TypeScript](examples/ts.md)
- [C#](examples/csharp.md)
