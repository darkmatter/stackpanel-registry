# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.cue;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:cue";

  options.stackpanel.languages.cue = {
    enable = lib.mkEnableOption "tools for Cue development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cue;
      defaultText = lib.literalExpression "pkgs.cue";
      description = "The CUE package to use.";
    };

    lsp = {
      enable = lib.mkEnableOption "CUE Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.cuelsp;
        defaultText = lib.literalExpression "pkgs.cuelsp";
        description = "The CUE language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "cue";
      meta = {
        name = "CUE";
        description = "CUE language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "cue";
      };
      enablePath = "languages.cue.enable";
      configPath = "languages.cue";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
        };
      };
    })
  ];
}
