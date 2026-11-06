# shellcheck shell=bash
# Part of doctor.sh, inlined into it at build time.
# The repo you are standing in, when you are in one: is it set up the way
# repoconfig leaves it.

check_repo() {
  local root
  root=$(git rev-parse --show-toplevel)

  if [ ! -f "$root/mise.toml" ] && [ ! -f "$root/.mise.toml" ]; then
    warn "not set up" "\`$PREFIX repo init <preset> <email>\`"
    return
  fi

  # Asking mise about a sandboxed repo would read its config on the host,
  # which is what the sandbox is for avoiding.
  if [ "$(git -C "$root" config --bool repoconfig.sandbox 2>/dev/null)" = true ]; then
    ok "sandboxed, checked in the container instead (see docs/sandbox.md)"
    return
  fi

  if [ -n "$(git -C "$root" config --local user.email)" ]; then
    ok "git identity is set for this repo"
  else
    warn "no local git identity" "\`$PREFIX repo init <preset> <email>\`"
  fi

  command -v mise >/dev/null || return 0
  if (cd "$root" && mise trust --show 2>/dev/null) | grep -q ': untrusted'; then
    fail "mise.toml is not trusted, so mise ignores it" "\`mise trust\`, after reading it"
    return
  fi
  ok "mise.toml is trusted"

  if [ -f "$root/mise.lock" ]; then
    ok "mise.lock is there"
  else
    warn "no mise.lock, so nothing is pinned" "\`touch mise.lock && mise install && mise lock\`"
  fi

  if [ -z "$(cd "$root" && mise ls --current --missing 2>/dev/null)" ]; then
    ok "every tool is installed"
  else
    warn "some tools are not installed" "\`mise install\`"
  fi
}
