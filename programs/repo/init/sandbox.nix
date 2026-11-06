# -----------------------------------------------------------------
# --sandbox: a dev container for a repo you do not trust.
#
# The editor server, extensions, language servers, installs and tests all run
# inside it, and only the repo is mounted: no home, no /mnt/c, no interop, no
# Docker socket. Sandboxing only `pnpm install` would leave the editor running
# the same dependencies outside it. See docs/sandbox.md.
#
# The files are mine, not the project's, so they go in .git/info/exclude like
# mise.local.toml. The image and features are what `mise generate devcontainer`
# produces; mise then installs from the committed mise.toml and mise.lock, so
# the container gets the same versions as the host.
#
# Credential forwarding is switched off in the Windows user settings by
# programs/tool/vscode-sync, because that is where Dev Containers reads it from. The two
# settings below are the editor's own git auth, which is per window and so can
# be set here. check-sandbox.sh runs on every attach and is the backstop that
# says so when any of it is not holding.
# -----------------------------------------------------------------

{ pkgs }:

{
  check = pkgs.writeText "check-sandbox.sh" (builtins.readFile ./check-sandbox.sh);

  # devcontainer.json for a preset, given that preset's plugins.
  devcontainerJson = name: exts:
    pkgs.writeText "devcontainer-${name}.json" (builtins.toJSON {
      name = "sandbox";
      image = "mcr.microsoft.com/devcontainers/base:ubuntu";
      features."ghcr.io/devcontainers-extra/features/mise:1" = { };
      # The workspace path differs from the host's, so mise needs trusting again.
      postCreateCommand = "mise trust && mise install && if mise tasks info setup >/dev/null 2>&1; then mise run setup; fi";
      postAttachCommand = "sh .devcontainer/check-sandbox.sh";
      customizations.vscode = {
        extensions = [ "hverlin.mise-vscode" ] ++ exts;
        settings = {
          "github.gitAuthentication" = false;
          "git.terminalAuthentication" = false;
        };
      };
    });
}
