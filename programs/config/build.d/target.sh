# shellcheck shell=bash
# Part of build.sh, inlined into it at build time.
# Which checkout to build, and what is in it.

# A NixOS config for this host, as opposed to any other repo with a flake.
is_config_checkout() { # directory
  [ -f "$1/flake.nix" ] && grep -q "nixosConfigurations\.$HOST_NAME\b" "$1/flake.nix"
}

# Sets CHECKOUT: the directory given, else the repo you are in when it is a
# config checkout, which is what makes a branch or a second clone work like
# `.#host` does, else /etc/nixos.
find_checkout() { # [directory]
  local here
  if [ -n "$1" ]; then
    CHECKOUT=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) \
      || die "$1 is not a git repository"
  elif here=$(git rev-parse --show-toplevel 2>/dev/null) && is_config_checkout "$here"; then
    CHECKOUT=$here
  else
    CHECKOUT=$(repo_root) || die "/etc/nixos does not resolve to a git repository"
  fi
  is_config_checkout "$CHECKOUT" \
    || die "$CHECKOUT has no nixosConfigurations.$HOST_NAME in its flake.nix"
}

describe_checkout() {
  local branch rev dirty=""
  branch=$(git -C "$CHECKOUT" symbolic-ref --short -q HEAD || echo "detached")
  rev=$(git -C "$CHECKOUT" rev-parse --short HEAD)
  git -C "$CHECKOUT" diff-index --quiet HEAD -- || dirty=", with uncommitted changes"
  info "Building $CHECKOUT ($branch at $rev$dirty)"
}

# A flake in a git repo only sees tracked files, so a new file that is not
# added yet is silently left out, and the error, if any, names a missing path.
warn_on_untracked_files() {
  local untracked
  untracked=$(git -C "$CHECKOUT" ls-files --others --exclude-standard | wc -l)
  if [ "$untracked" -gt 0 ]; then
    warn "$untracked untracked files are not part of the build. \`git add\` the ones it needs."
  fi
}
