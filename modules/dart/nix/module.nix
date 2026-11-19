# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.dart;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:dart";

  options.stackpanel.languages.dart = {
    enable = lib.mkEnableOption "tools for Dart development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dart;
      defaultText = lib.literalExpression "pkgs.dart";
      description = "The Dart package to use.";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "dart";
      meta = {
        name = "Dart";
        description = "Dart language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "dart";
      };
      enablePath = "languages.dart.enable";
      configPath = "languages.dart";
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
