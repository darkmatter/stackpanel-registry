# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.raku;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:raku";

  options.stackpanel.languages.raku = {
    enable = lib.mkEnableOption "tools for Raku development";
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "raku";
      meta = {
        name = "Raku";
        description = "Raku language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "raku";
      };
      enablePath = "languages.raku.enable";
      configPath = "languages.raku";
      features.packages = true;
      packages =
        _: with pkgs; [
          rakudo
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
