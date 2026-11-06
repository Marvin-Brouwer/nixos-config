# shellcheck shell=bash
# Part of update.sh, inlined into it at build time.
# The checkout to pull, whether it is in a state to be pulled, and getting it
# onto main.

# Sets REPO, and BEFORE: the commit checked out now, to tell afterwards
# whether anything changed.
enter_checkout() {
  REPO=$(repo_root) || die "/etc/nixos does not resolve to a git repository"
  cd "$REPO" || die "cannot enter $REPO"
  BEFORE=$(git rev-parse HEAD)
}

# Tracked changes only. Untracked files are left alone, and git itself refuses
# a checkout or a fast-forward that would overwrite one. Nothing is stashed on
# your behalf: a stash is easy to forget, and on this repo forgetting one means
# a change you thought was in the system and is not.
require_clean_tree() {
  git diff-index --quiet HEAD -- \
    || die "$REPO has uncommitted changes. Commit or stash them first, or \`$PREFIX config build\` to build them as they are."
}

# Sets FROM to the branch you were on, empty when that was main already.
# A local main is made when there is none yet, tracking the remote one.
switch_to_main() {
  local current
  current=$(git symbolic-ref --short -q HEAD || echo "")
  FROM=""
  [ "$current" = "$BRANCH" ] && return 0

  FROM=${current:-"a detached HEAD"}
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git switch -q "$BRANCH" || die "could not switch to $BRANCH, see the output above"
  else
    git switch -q -c "$BRANCH" --track "$REMOTE/$BRANCH" \
      || die "could not create $BRANCH from $REMOTE/$BRANCH, see the output above"
  fi
  info "Switched from $FROM to $BRANCH."
  [ -n "$current" ] && note_merged_branch "$current"
}

# Says so when the branch you left is merged and gone from the remote, which
# is the usual reason to be back on main. Leaves deleting it to you.
note_merged_branch() { # branch
  git merge-base --is-ancestor "$1" "$REMOTE/$BRANCH" || return 0
  git show-ref --verify --quiet "refs/remotes/$REMOTE/$1" && return 0
  info "$1 is merged into $BRANCH and gone from $REMOTE. \`git branch -d $1\` removes it."
}
