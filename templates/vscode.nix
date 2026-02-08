{ pkgs }:

# -----------------------------------------------------------------
# Base list of extensions that all profiles inherit.
#
# Extensions not packaged in nixpkgs can be installed via VSCode's
# built-in marketplace (Ctrl+Shift+X). Missing extensions are listed
# at the bottom of this file for reference.
# -----------------------------------------------------------------
let
  base = [
    pkgs.vscode-extensions.jnoortheen.nix-ide
    pkgs.vscode-extensions.dbaeumer.vscode-eslint
    pkgs.vscode-extensions.esbenp.prettier-vscode
    pkgs.vscode-extensions.streetsidesoftware.code-spell-checker
    pkgs.vscode-extensions.mechatroner.rainbow-csv
    pkgs.vscode-extensions.editorconfig.editorconfig
    pkgs.vscode-extensions.tomoki1207.pdf
    pkgs.vscode-extensions.dotjoshjohnson.xml
    pkgs.vscode-extensions.redhat.vscode-yaml
    pkgs.vscode-extensions.anweber.vscode-httpyac
    pkgs.vscode-extensions.dotenv.dotenv-vscode
    pkgs.vscode-extensions.oderwat.indent-rainbow
    pkgs.vscode-extensions.tyriar.sort-lines
    pkgs.vscode-extensions.vscode-icons-team.vscode-icons
    pkgs.vscode-extensions.vincaslt.highlight-matching-tag
    pkgs.vscode-extensions.wmaurer.change-case
    pkgs.vscode-extensions.formulahendry.auto-rename-tag
    pkgs.vscode-extensions.mads-hartmann.bash-ide-vscode
    pkgs.vscode-extensions.funkyremi.vscode-google-translate
  ];

  # Not packaged in nixpkgs — install these via VSCode marketplace:
  #   streetsidesoftware.code-spell-checker-dutch
  #   qiaojie.binary-viewer (or ms-vscode.hexeditor)
  #   anseki.vscode-color
  #   unifiedjs.vscode-remark
  #   hgent.json-field-filter
  #   oliversturm.fix-json
  #   richie5um2.vscode-statusbar-json-path
  #   motivesoft.vscode-restart
  #   maattdd.gitless (or eamodio.gitlens)
  #   joshuapoehls.json-escaper
  #   ExodiusStudios.comment-anchors
  #   stuart.unique-window-colors
  #   kisstkondoros.vscode-gutter-preview
  #   midudev.better-svg
  #   pomdtr.excalidraw-editor
  #   MermaidChart.vscode-mermaid-chart
  #   DutchIgor.json-viewer
  #   Tion.evenbettercomments
  #   hediet.debug-visualizer
  #   heaths.vscode-guid
  #   lamartire.git-indicators
  #   meronz.manpages
in

{ extra ? [] }:

pkgs.vscode-with-extensions.override {
  vscodeExtensions = base ++ extra;
}
