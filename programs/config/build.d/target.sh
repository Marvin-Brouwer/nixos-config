# shellcheck shell=bash
# Part of build.sh, inlined into it at build time.
# Which checkout to build, and what is in it.

# Sets CHECKOUT: always the one /etc/nixos points at, which is the checkout
# the machine is built from, on whatever branch it is on.
find_checkout() {
  CHECKOUT=$(repo_root) || die "/etc/nixos does not resolve to a git repository"
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
