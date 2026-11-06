# shellcheck shell=bash
# Part of repoconfig.sh, inlined into it at build time.
# --sandbox: the dev container. The run ends after this, before anything
# touches the network or runs the repo's config on the host.

# A repo with its own .devcontainer keeps it, and is not excluded either:
# that one is the project's, and whether it forwards anything is up to it.
write_sandbox() {
  # Marks the repo for vscode-sync, which then leaves the host's plugins
  # alone here: the repo's own extensions.json is as untrusted as the rest.
  git config --local repoconfig.sandbox true
  say "repoconfig.sandbox: vscode-sync skips this repo"

  if [ -f .devcontainer/check-sandbox.sh ]; then
    kept ".devcontainer/ (sandbox)"
  elif [ -e .devcontainer ]; then
    kept ".devcontainer/ (the project's own; check it before trusting it as a sandbox)"
  else
    mkdir -p .devcontainer
    jq . "$DEVCONTAINER_SRC" > .devcontainer/devcontainer.json
    cp "$SANDBOX_CHECK" .devcontainer/check-sandbox.sh
    chmod +w .devcontainer/check-sandbox.sh
    made ".devcontainer/ (sandbox)"
    exclude_devcontainer
  fi
}

exclude_devcontainer() {
  if grep -qxF ".devcontainer/" "$EXCLUDE" 2>/dev/null; then
    kept "$EXCLUDE entry for .devcontainer/"
  else
    printf '%s\n' ".devcontainer/" >> "$EXCLUDE"
    made "$EXCLUDE entry for .devcontainer/"
  fi
}
