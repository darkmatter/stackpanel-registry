# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.lobster;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:lobster";

  options.stackpanel.languages.lobster = {
    enable = lib.mkEnableOption "tools for Lobster development";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which Lobster package to use.";
      default = pkgs.lobster;
      defaultText = lib.literalExpression "pkgs.lobster";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "lobster";
      meta = {
        name = "Lobster";
        description = "Lobster language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "lobster";
      };
      enablePath = "languages.lobster.enable";
      configPath = "languages.lobster";
      features.packages = true;
      packages = _: [
        cfg.package
      ];
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
