# Sandbox

A dev container for a repo you do not trust: someone else's project, a
take-home assignment, anything with a dependency tree you have not looked at.

```bash
cd ~/repos/some-project
rig repoconfig ts me@example.com --sandbox
```

Then open the folder in VS Code and run **Dev Containers: Reopen in Container**.

## Why a container and not a sandboxed command

The risky code is a dependency: an npm install script, a NuGet build target, an
analyzer or source generator. That code doesn't only run on `pnpm install`. The
editor runs it too, through the language server, eslint plugins, test runners
and the build. Sandboxing the install command alone would leave the editor
running the same packages outside the sandbox.

With a dev container, the VS Code server and everything it starts run inside
the container. That's why this uses Dev Containers rather than
`systemd-run`, bubblewrap or an nspawn container.

## What `--sandbox` does differently

| step | normal | `--sandbox` |
| --- | --- | --- |
| git identity, `mise.toml`, `mise.lock`, `extensions.json`, preset files | yes | yes |
| `mise trust` | on the host | in the container |
| `mise install`, `mise lock`, `vscode-sync` | on the host | skipped |
| `.devcontainer/` | no | written, and added to `.git/info/exclude` |
| `repoconfig.sandbox` git config | no | `true` |

Trust is skipped on the host because a trusted `mise.toml` can run code when
you enter the directory (env sources, hooks), and an untrusted repo may ship
its own. `repoconfig.sandbox` makes `vscode-sync` skip the repo, so a hostile
`.vscode/extensions.json` can't install plugins on the host. The container's
plugins come from the preset, in `devcontainer.json`.

If the repo already has a `.devcontainer/`, it's kept and nothing is written.
In that case the project's container is not a sandbox until you have read it.
Mounts, `runArgs` and features can put back everything this page is about.

## What the container can't reach

Only the repo is mounted, at `/workspaces/<name>`. There's no home directory, so
no `~/.ssh`, no tokens and no shell history. There's no `/mnt/c` and no Docker
socket. mise installs from the committed `mise.toml` and `mise.lock`, so you
get the same versions as on the host.

## Credential forwarding

By default the Dev Containers extension hands your credentials to every
container. It copies your `.gitconfig`, installs a git credential helper that
calls back to the host, and forwards Docker registry credentials and a `gh`
login. That's the opposite of what a sandbox is for, so `vscode-sync` turns it
off in the Windows VS Code user settings:

```jsonc
"dev.containers.copyGitConfig": false,
"dev.containers.gitCredentialHelperConfigLocation": "none",
"dev.containers.dockerCredentialHelper": false,
"dev.containers.githubCLILoginWithToken": false
```

These are user settings, so they apply to **every** dev container, not just
sandboxes. Commit inside the container if you like; the repo's own
`.git/config` carries the identity. **Push from a host terminal.**

The editor's own git authentication is per window, so the sandbox's
`devcontainer.json` turns that off itself (`github.gitAuthentication`,
`git.terminalAuthentication`).

I couldn't find an off switch for SSH agent forwarding that I could verify.
The extension forwards an agent when one is running on the host. This config
doesn't start one, so there's nothing to forward unless you run one yourself.
GPG is the same story, since `gnupg` is installed but no agent is set up. The
attach check below flags both.

## The attach check

`.devcontainer/check-sandbox.sh` runs on every attach and prints a red line for
each leak it finds: a forwarded SSH or GPG agent, a git credential helper, the editor's
git askpass, Docker registry credentials, the Docker socket, or `/mnt/c`. When
it's clean it says `sandbox: no forwarded credentials found`. If it's red, fix
the cause before installing anything.

## What this does not protect

- **The repo itself.** Anything inside it is mounted read-write, including a
  `.env` you put there. Don't put secrets in a sandboxed repo.
- **The network.** The container has normal outbound access, so code inside it
  can still send out whatever it can read.
- **The editor link.** The VS Code server inside can still open URLs in your
  browser and forward ports to Windows. It can't run commands on the host that
  way, but it isn't nothing.
- **A container escape.** Docker runs as root here, so an escape is root in
  WSL. Containers are a strong default, not a hard boundary.
- **Interop from inside.** WSL registers Windows `.exe` handling kernel-wide.
  It should fail in a container because the interop socket isn't there, but
  that's reasoning, not something I've tested.

## Costs

The first open builds an image and installs the tools, which takes minutes, not
seconds. Docker has to be running (the first `docker` command starts it). The
Windows side gains `ms-vscode-remote.remote-containers`, which `vscode-sync`
installs next to the WSL extension.
