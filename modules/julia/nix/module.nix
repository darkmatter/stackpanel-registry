# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.julia;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:julia";

  options.stackpanel.languages.julia = {
    enable = lib.mkEnableOption "tools for Julia development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.julia-bin;
      defaultText = lib.literalExpression "pkgs.julia-bin";
      description = "The Julia package to use.";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "julia";
      meta = {
        name = "Julia";
        description = "Julia language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "julia";
      };
      enablePath = "languages.julia.enable";
      configPath = "languages.julia";
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
