#!/bin/sh
# Runs on every attach. Warns when the editor forwarded a host credential
# into this container, which is the thing the container is here to prevent.
leak=0
warn() { printf '\033[1;31msandbox:\033[0m %s\n' "$1"; leak=1; }

[ -n "${SSH_AUTH_SOCK:-}" ] && warn "an SSH agent is forwarded ($SSH_AUTH_SOCK)"
for sock in /tmp/vscode-ssh-auth-*.sock; do
  [ -S "$sock" ] && warn "an SSH agent socket is present ($sock)"
done
[ -S "$HOME/.gnupg/S.gpg-agent" ] && warn "a GPG agent is forwarded"
helper="$(git config --get-all credential.helper 2>/dev/null)"
[ -n "$helper" ] && warn "git has a credential helper: $helper"
[ -n "${VSCODE_GIT_ASKPASS_MAIN:-}" ] && warn "the editor's git askpass reaches terminals"
grep -qs credsStore "$HOME/.docker/config.json" && warn "Docker registry credentials are forwarded"
[ -S /var/run/docker.sock ] && warn "the Docker socket is mounted"
[ -d /mnt/c ] && warn "/mnt/c is visible"

if [ "$leak" -eq 0 ]; then
  echo "sandbox: no forwarded credentials found"
else
  echo "sandbox: see docs/sandbox.md in nixos-config"
fi
