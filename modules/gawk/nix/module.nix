# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.gawk;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:gawk";

  options.stackpanel.languages.gawk = {
    enable = lib.mkEnableOption "tools for GNU Awk development";
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "gawk";
      meta = {
        name = "GNU Awk";
        description = "GNU Awk language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "gawk";
      };
      enablePath = "languages.gawk.enable";
      configPath = "languages.gawk";
      features.packages = true;
      packages =
        _: with pkgs; [
          gawk
          gawkextlib.gawkextlib
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
