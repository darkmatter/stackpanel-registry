# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.gleam;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:gleam";

  options.stackpanel.languages.gleam = {
    enable = lib.mkEnableOption "tools for Gleam development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gleam;
      description = "The Gleam package to use.";
      defaultText = lib.literalExpression "pkgs.gleam";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "gleam";
      meta = {
        name = "Gleam";
        description = "Gleam language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "gleam";
      };
      enablePath = "languages.gleam.enable";
      configPath = "languages.gleam";
      features.packages = true;
      requires = [ "erlang" ];
      packages = _: [
        cfg.package
      ];
      config = _: {
        stackpanel.languages.erlang.enable = true;

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
