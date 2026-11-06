# Scratch

A throwaway repo for trying something out in thirty seconds, without first
deciding where it should live:

```bash
rig scratch ts       # temp repo, ts preset, a shell in it
rig scratch          # the empty preset
rig scratch ts --keep
```

It runs `git init` in a new directory under `/tmp/scratch/`, then
`rig repoconfig <preset> scratch@localhost` in it, then opens your own shell
there, so your prompt and the mise hook come along. When you `exit`, it asks
whether to delete the directory. The default is yes. `--keep` skips the
question and keeps it.

Since it's an ordinary repoconfig run, you get the preset's `mise.toml`,
`mise.lock`, plugins and `setup` task, the same as a real project. The git
identity is `scratch@localhost`, because nothing pushes from a scratch repo.

To promote one into a real project, keep it and move it:

```bash
mv /tmp/scratch/ts-1106-AbCd ~/repos/my-idea
cd ~/repos/my-idea
git config --local user.email me@example.com
```
