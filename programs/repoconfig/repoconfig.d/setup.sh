# shellcheck shell=bash
# Part of repoconfig.sh, inlined into it in order at build time.
# The local setup, from git identity to .git/info/exclude.

# --- git identity ---
git config --local user.name "$GIT_USER_NAME"
git config --local user.email "$EMAIL"
say "git identity: $GIT_USER_NAME <$EMAIL>"

# --- mise.toml ---
if [ -f mise.toml ] || [ -f .mise.toml ]; then
  kept "mise.toml"
else
  cp "$MISE_SRC" mise.toml
  chmod +w mise.toml
  made "mise.toml"
fi

# --- trust, before anything reads the config ---
# Not for a sandbox. A trusted mise.toml can run code on entering the
# directory (env sources, hooks), and an untrusted repo may have brought its
# own. The container trusts it instead, where that code cannot reach home.
if [ -n "$SANDBOX" ]; then
  say "mise trust: skipped, the container does it"
else
  if mise trust >/dev/null 2>&1; then
    say "mise trust"
  else
    say "mise trust: nothing to do"
  fi
fi

# --- lockfile ---
# mise will not create this itself, and stays silent when it is absent, so a
# repo without it quietly gets no pinning at all.
if [ -f mise.lock ]; then
  kept "mise.lock"
else
  touch mise.lock
  made "mise.lock"
fi

# --- vscode plugins ---
if [ -f .vscode/extensions.json ]; then
  kept ".vscode/extensions.json"
else
  mkdir -p .vscode
  jq . "$EXT_SRC" > .vscode/extensions.json
  made ".vscode/extensions.json"
fi

# --- preset files ---
install_extra() {
  if [ -e "$1" ]; then
    kept "$1"
  else
    cp "$2" "$1"
    chmod +w "$1"
    made "$1"
  fi
}

# Top level only: a preset file goes in the repo root.
for src in "$PRESET_DIR"/files/*; do
  [ -e "$src" ] || continue
  install_extra "$(basename "$src")" "$src"
done

# --- local ignores ---
# .git/info/exclude rather than .gitignore: personal tooling should not turn
# up in other people's diffs. mise.toml and mise.lock are meant to be
# committed, so only the local override file is excluded.
EXCLUDE=".git/info/exclude"
mkdir -p "$(dirname "$EXCLUDE")"
if grep -qxF "mise.local.toml" "$EXCLUDE" 2>/dev/null; then
  kept "$EXCLUDE entry"
else
  printf '%s\n' "mise.local.toml" >> "$EXCLUDE"
  made "$EXCLUDE entry for mise.local.toml"
fi
