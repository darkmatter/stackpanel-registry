# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.r;
  rPackage =
    if cfg.lsp.enable then
      pkgs.rWrapper.override {
        R = cfg.package;
        packages = [ cfg.lsp.package ];
      }
    else
      cfg.package;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:r";

  options.stackpanel.languages.r = {
    enable = lib.mkEnableOption "tools for R development";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.R;
      defaultText = lib.literalExpression "pkgs.R";
      description = "The R package to use.";
    };
    radian = {
      enable = lib.mkEnableOption "a 21 century R console";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.radianWrapper;
        defaultText = lib.literalExpression "pkgs.radianWrapper";
        description = "The radian package to use.";
      };
    };

    lsp = {
      enable = lib.mkEnableOption "R Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.rPackages.languageserver;
        defaultText = lib.literalExpression "pkgs.rPackages.languageserver";
        description = "The R language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "r";
      meta = {
        name = "R";
        description = "R language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "r";
      };
      enablePath = "languages.r.enable";
      configPath = "languages.r";
      features.packages = true;
      packages = _: [ rPackage ] ++ lib.optional cfg.radian.enable cfg.radian.package;
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
