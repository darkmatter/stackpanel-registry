# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.pascal;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:pascal";

  options.stackpanel.languages.pascal = {
    enable = lib.mkEnableOption "tools for Pascal development";

    lazarus = {
      enable = lib.mkEnableOption "lazarus graphical IDE for the FreePascal language";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "pascal";
      meta = {
        name = "Pascal";
        description = "Pascal language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "pascal";
      };
      enablePath = "languages.pascal.enable";
      configPath = "languages.pascal";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          fpc
        ]
        ++ lib.optional (cfg.lazarus.enable && pkgs.stdenv.hostPlatform.isLinux) pkgs.lazarus;
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
