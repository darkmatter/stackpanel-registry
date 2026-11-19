# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.racket;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:racket";

  options.stackpanel.languages.racket = {
    enable = lib.mkEnableOption "tools for Racket development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.racket-minimal;
      defaultText = lib.literalExpression "pkgs.racket-minimal";
      description = "The Racket package to use.";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "racket";
      meta = {
        name = "Racket";
        description = "Racket language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "racket";
      };
      enablePath = "languages.racket.enable";
      configPath = "languages.racket";
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
