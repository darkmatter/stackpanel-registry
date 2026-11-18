# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.robotframework;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:robotframework";

  options.stackpanel.languages.robotframework = {
    enable = lib.mkEnableOption "tools for Robot Framework development";

    python = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3;
      defaultText = lib.literalExpression "pkgs.python3";
      description = "The Python package to use.";
    };

  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "robotframework";
      meta = {
        name = "Robot Framework";
        description = "Robot Framework language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "robotframework";
      };
      enablePath = "languages.robotframework.enable";
      configPath = "languages.robotframework";
      features.packages = true;
      packages = _: [
        (cfg.python.withPackages (ps: [
          ps.robotframework
        ]))
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
