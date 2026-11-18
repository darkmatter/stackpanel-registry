# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.typst;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:typst";

  options.stackpanel.languages.typst = {
    enable = lib.mkEnableOption "tools for Typst development";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which package of Typst to use.";
      default = pkgs.typst;
      defaultText = lib.literalExpression "pkgs.typst";
    };

    fontPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Directories to be searched for fonts.";
      default = [ ];
      defaultText = lib.literalExpression "[]";
      example = lib.literalExpression ''[ "''${pkgs.roboto}/share/fonts/truetype" ]'';
    };

    lsp = {
      enable = lib.mkEnableOption "Typst Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.tinymist;
        defaultText = lib.literalExpression "pkgs.tinymist";
        description = "The Typst language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "typst";
      meta = {
        name = "Typst";
        description = "Typst language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "typst";
      };
      enablePath = "languages.typst.enable";
      configPath = "languages.typst";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
          pkgs.typstyle # formatter
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
          TYPST_FONT_PATHS = lib.mkIf (cfg.fontPaths != [ ]) (lib.concatStringsSep ":" cfg.fontPaths);
        };
      };
    })
  ];
}
