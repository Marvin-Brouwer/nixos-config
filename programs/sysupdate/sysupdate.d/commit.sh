# shellcheck shell=bash
# Part of sysupdate.sh, inlined into it at build time.
# commit_lock and push_lock, used by apply.sh.

# Committing is what makes the machine reproducible and what carries the
# bump to the other machine. Path-scoped so an unrelated staged change
# cannot be swept into it.
commit_lock() {
  if [ -z "$(git config user.email)" ]; then
    warn "no git user.email in this repo, leaving flake.lock uncommitted"
    return 0
  fi

  local subject body
  subject="flake.lock: update $(printf '%s, ' "${CHOSEN[@]}" | sed 's/, $//')"
  body=$(jq -r --args '
    . as $revs | $ARGS.positional[]
    | "\(.): \($revs[.].old[:7]) -> \($revs[.].new[:7])  (\($revs[.].old_date) -> \($revs[.].new_date))"
  ' "${CHOSEN[@]}" < "$TMP/applied.json")

  if git commit -q -m "$subject" -m "$body" -- flake.lock; then
    info "Committed the flake.lock bump."
    push_lock
  else
    warn "could not commit flake.lock, it is left in the working tree"
  fi
}

# Pushing is what carries the bump to the other machine, and only ever
# follows a commit, which only ever follows a successful switch or boot.
# A failed push is a warning, not a failure: the system is already
# activated and the commit is safe locally, so the run itself succeeded.
push_lock() {
  local upstream
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || {
    warn "this branch has no upstream, leaving the commit unpushed"
    return 0
  }

  info "Pushing to $upstream..."
  if git push -q; then
    info "Pushed."
  else
    warn "could not push to $upstream, the commit is still local. Push it by hand."
  fi
}
