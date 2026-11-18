# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.lean4;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:lean4";

  options.stackpanel.languages.lean4 = {
    enable = lib.mkEnableOption "tools for lean4 development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.lean4;
      defaultText = lib.literalExpression "pkgs.lean4";
      description = ''
        The lean4 package to use.
      '';
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "lean4";
      meta = {
        name = "Lean 4";
        description = "Lean 4 language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "lean4";
      };
      enablePath = "languages.lean4.enable";
      configPath = "languages.lean4";
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
