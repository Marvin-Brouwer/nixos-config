# shellcheck shell=bash
# Part of update.sh, inlined into it at build time.
# Fetching main, fast-forwarding to it, and whether that changed anything.

# The whole remote rather than the current branch's upstream, which is what
# `git pull` fetches and what fails once that branch is deleted. --prune drops
# the refs of branches deleted there, which is also how note_merged_branch
# tells a merged branch is gone.
fetch_main() {
  info "Fetching $REMOTE..."
  git fetch -q --prune "$REMOTE" || die "could not fetch from $REMOTE"
  git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH" \
    || die "$REMOTE has no $BRANCH branch"
}

# Compared first rather than `git merge --ff-only` and its failure read back:
# each case gets its own answer.
fast_forward_main() {
  local upstream="$REMOTE/$BRANCH"
  if git merge-base --is-ancestor "$upstream" HEAD; then
    if [ "$(git rev-parse HEAD)" = "$(git rev-parse "$upstream")" ]; then
      info "$BRANCH is up to date with $upstream."
    else
      info "$BRANCH is ahead of $upstream, nothing to pull. \`git push\` sends your commits."
    fi
    return 0
  fi
  git merge-base --is-ancestor HEAD "$upstream" \
    || die "$BRANCH and $upstream have diverged. Rebase or merge by hand, then run \`$PREFIX config build\`."
  git merge -q --ff-only "$upstream" || die "the fast-forward failed, see the output above"
}

stop_if_unchanged() {
  [ "$(git rev-parse HEAD)" = "$BEFORE" ] || return 0
  info "Nothing changed, nothing to build. \`$PREFIX config build\` rebuilds anyway."
  exit 0
}

# Only when the old commit is behind the new one. Coming from a branch, the
# log would be main's history since that branch forked, which says little.
list_new_commits() {
  git merge-base --is-ancestor "$BEFORE" HEAD || return 0
  echo
  git --no-pager log --oneline --no-decorate "$BEFORE..HEAD"
  echo
}
