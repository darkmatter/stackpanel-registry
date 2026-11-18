# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.hare;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:hare";

  options.stackpanel.languages.hare = {
    enable = lib.mkEnableOption "tools for Hare development";
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "hare";
      meta = {
        name = "Hare";
        description = "Hare language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "hare";
      };
      enablePath = "languages.hare.enable";
      configPath = "languages.hare";
      features.packages = true;
      packages =
        _: with pkgs; [
          hare
          haredoc
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
