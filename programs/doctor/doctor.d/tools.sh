# shellcheck shell=bash
# Part of doctor.sh, inlined into it at build time.
# What the toolchain needs to start at all.

# Without nix-ld every vendor binary mise installs fails to start, with a
# "No such file or directory" for a file that is plainly there.
check_nix_ld() {
  if [ -n "${NIX_LD:-}" ] && [ -e "$NIX_LD" ]; then
    ok "nix-ld is active"
  else
    fail "nix-ld is not active in this shell" \
      "mise-installed tools will not start; open a new shell, or rebuild"
  fi
}

# Without the filters LFS files check out as pointer stubs, silently.
check_git_lfs() {
  if git config --system --get filter.lfs.process >/dev/null 2>&1; then
    ok "git-lfs filters are registered"
  else
    fail "git-lfs filters are not registered" "programs.git.lfs.enable in configuration.nix"
  fi
}

check_mise() {
  if ! command -v mise >/dev/null; then
    fail "mise is not on PATH" "it comes from systemTools in configuration.nix"
    return
  fi
  if mise doctor >/dev/null 2>&1; then
    ok "mise doctor is happy"
  else
    warn "mise doctor reports problems" "\`mise doctor\`"
  fi
}

# mise checks node's release signature with gpg and only warns when it is
# missing, so a missing gpg quietly turns the check off.
check_gpg() {
  if command -v gpg >/dev/null; then
    ok "gpg is there for mise's signature checks"
  else
    warn "gpg is missing, mise skips node signature checks" "gnupg in systemTools"
  fi
}

# Only the socket is checked unless the daemon is already up: asking the
# daemon anything would start it, and this changes nothing.
check_docker() {
  if ! systemctl is-active --quiet docker.socket 2>/dev/null; then
    fail "the Docker socket is not listening" "\`systemctl status docker.socket\`"
  elif ! systemctl is-active --quiet docker.service 2>/dev/null; then
    ok "Docker socket listening, the daemon starts on first use"
  elif timeout 10 docker info >/dev/null 2>&1; then
    ok "Docker daemon answers"
  else
    fail "Docker daemon is running but does not answer" "\`journalctl -u docker -b\`"
  fi

  if id -nG | grep -qw docker; then
    ok "you are in the docker group"
  else
    warn "you are not in the docker group yet" "log in again: \`wsl --shutdown\` from Windows"
  fi
}

check_binary_cache() {
  if curl -sf --max-time 5 -o /dev/null https://cache.nixos.org/nix-cache-info; then
    ok "cache.nixos.org is reachable"
  else
    fail "cache.nixos.org is not reachable" "no network, or a proxy or VPN in the way"
  fi
}
