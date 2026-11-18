# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.v;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:v";

  options.stackpanel.languages.v = {
    enable = lib.mkEnableOption "tools for V development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vlang;
      defaultText = lib.literalExpression "pkgs.vlang";
      description = "The V package to use.";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "v";
      meta = {
        name = "V";
        description = "V language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "v";
      };
      enablePath = "languages.v.enable";
      configPath = "languages.v";
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
