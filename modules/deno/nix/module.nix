# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.deno;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:deno";

  options.stackpanel.languages.deno = {
    enable = lib.mkEnableOption "tools for Deno development";
    package = lib.mkOption {
      type = lib.types.package;
      description = "Which package of Deno to use.";
      default = pkgs.deno;
      defaultText = lib.literalExpression "pkgs.deno";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "deno";
      meta = {
        name = "Deno";
        description = "Deno language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "deno";
      };
      enablePath = "languages.deno.enable";
      configPath = "languages.deno";
      features.packages = true;
      packages = _: [
        cfg.package
      ];
      config = _: {
        stackpanel.devshell.hooks.main = [
          (''
            export PATH="$PATH:$DENO_INSTALL_ROOT/bin"
          '')
        ];

        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
          DENO_INSTALL_ROOT = config.stackpanel.devshell.env.DEVENV_STATE + "/deno";
          DENO_DIR = config.stackpanel.devshell.env.DENO_INSTALL_ROOT + "/cache";
        };
      };
    })
  ];
}
