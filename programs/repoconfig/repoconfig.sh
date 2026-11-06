# shellcheck shell=bash
# The `repoconfig` command. Not run as is: default.nix fills in the @-delimited
# placeholders.

set -uo pipefail

# --sandbox may go anywhere; the rest is positional.
SANDBOX=
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --sandbox) SANDBOX=1 ;;
    *) ARGS+=("$arg") ;;
  esac
done
PRESET="${ARGS[0]:-}"
EMAIL="${ARGS[1]:-}"

say()  { printf '   %s\n' "$*"; }
made() { printf '   \033[1;32mcreated\033[0m %s\n' "$*"; }
kept() { printf '   \033[1;33mkept\033[0m    %s (already present)\n' "$*"; }
die()  { printf '\033[1;31mrepoconfig:\033[0m %s\n' "$*" >&2; exit 1; }

case "$PRESET" in
  -h|--help) @coreutils@/bin/cat @help@; exit 0 ;;
  -l|--list) @coreutils@/bin/cat @list@; exit 0 ;;
esac

# One directory per preset, built by default.nix: mise.toml, extensions.json,
# devcontainer.json, and files/ for anything else the preset writes. Looked up
# by name rather than by path, so an argument like ../ cannot point it anywhere.
PRESETS=(@presetNames@)
PRESET_DIR=
for name in "${PRESETS[@]}"; do
  [ "$name" = "$PRESET" ] && PRESET_DIR="@presets@/$name"
done
[ -n "$PRESET_DIR" ] || die "@usage@ (presets: @prefix@ repoconfig --list)"
MISE_SRC="$PRESET_DIR/mise.toml"
EXT_SRC="$PRESET_DIR/extensions.json"
DEVCONTAINER_SRC="$PRESET_DIR/devcontainer.json"

[ -n "$EMAIL" ] || die "@usage@"

@git@/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "not inside a git repository"
REPO_ROOT="$(@git@/bin/git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || die "cannot enter $REPO_ROOT"

printf '\n\033[1;34m== %s (%s)\033[0m\n' "$(@coreutils@/bin/basename "$REPO_ROOT")" "$PRESET"

# --- git identity ---
@git@/bin/git config --local user.name "@gitUserName@"
@git@/bin/git config --local user.email "$EMAIL"
say "git identity: @gitUserName@ <$EMAIL>"

# --- mise.toml ---
if [ -f mise.toml ] || [ -f .mise.toml ]; then
  kept "mise.toml"
else
  @coreutils@/bin/cp "$MISE_SRC" mise.toml
  @coreutils@/bin/chmod +w mise.toml
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
  @coreutils@/bin/touch mise.lock
  made "mise.lock"
fi

# --- vscode plugins ---
if [ -f .vscode/extensions.json ]; then
  kept ".vscode/extensions.json"
else
  @coreutils@/bin/mkdir -p .vscode
  @jq@/bin/jq . "$EXT_SRC" > .vscode/extensions.json
  made ".vscode/extensions.json"
fi

# --- preset files ---
install_extra() {
  if [ -e "$1" ]; then
    kept "$1"
  else
    @coreutils@/bin/cp "$2" "$1"
    @coreutils@/bin/chmod +w "$1"
    made "$1"
  fi
}

# Top level only: a preset file goes in the repo root.
for src in "$PRESET_DIR"/files/*; do
  [ -e "$src" ] || continue
  install_extra "$(@coreutils@/bin/basename "$src")" "$src"
done

# --- local ignores ---
# .git/info/exclude rather than .gitignore: personal tooling should not turn
# up in other people's diffs. mise.toml and mise.lock are meant to be
# committed, so only the local override file is excluded.
EXCLUDE=".git/info/exclude"
@coreutils@/bin/mkdir -p "$(@coreutils@/bin/dirname "$EXCLUDE")"
if @gnugrep@/bin/grep -qxF "mise.local.toml" "$EXCLUDE" 2>/dev/null; then
  kept "$EXCLUDE entry"
else
  printf '%s\n' "mise.local.toml" >> "$EXCLUDE"
  made "$EXCLUDE entry for mise.local.toml"
fi

# --- sandbox ---
# A repo with its own .devcontainer keeps it, and is not excluded either:
# that one is the project's, and whether it forwards anything is up to it.
if [ -n "$SANDBOX" ]; then
  # Marks the repo for vscode-sync, which then leaves the host's plugins
  # alone here: the repo's own extensions.json is as untrusted as the rest.
  @git@/bin/git config --local repoconfig.sandbox true
  say "repoconfig.sandbox: vscode-sync skips this repo"
  if [ -f .devcontainer/check-sandbox.sh ]; then
    kept ".devcontainer/ (sandbox)"
  elif [ -e .devcontainer ]; then
    kept ".devcontainer/ (the project's own; check it before trusting it as a sandbox)"
  else
    @coreutils@/bin/mkdir -p .devcontainer
    @jq@/bin/jq . "$DEVCONTAINER_SRC" > .devcontainer/devcontainer.json
    @coreutils@/bin/cp @sandboxCheck@ .devcontainer/check-sandbox.sh
    @coreutils@/bin/chmod +w .devcontainer/check-sandbox.sh
    made ".devcontainer/ (sandbox)"
    if @gnugrep@/bin/grep -qxF ".devcontainer/" "$EXCLUDE" 2>/dev/null; then
      kept "$EXCLUDE entry for .devcontainer/"
    else
      printf '%s\n' ".devcontainer/" >> "$EXCLUDE"
      made "$EXCLUDE entry for .devcontainer/"
    fi
  fi
fi

# The sandbox stops here: every step below runs the repo's config on the
# host, which is exactly what it is for avoiding.
if [ -n "$SANDBOX" ]; then
  printf '\n   Done. Open the repo in VS Code and run "Dev Containers: Reopen in Container".\n\n'
  exit 0
fi

# --- resolve and lock, last ---
# Everything above is local and instant. This talks to the network and can
# take a minute on a fresh preset, so it goes at the end: a failure or a
# ctrl-c here leaves the repo already set up rather than half configured.
mise install || say "mise install reported a problem, see above"
mise lock --platform linux-x64,windows-x64 || say "mise lock reported a problem, see above"

# Run the sync here rather than telling you to cd out and back in. The mise
# enter hook lives in the interactive shell, so it cannot be triggered from
# inside this script; calling it directly does the same job. The repo has a
# mise.toml and is trusted by now, so the guard lets it through.
echo
@vscodeSync@/bin/vscode-sync

printf '\n   Done.\n\n'
