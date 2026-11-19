# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.unison;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:unison";

  options.stackpanel.languages.unison = {
    enable = lib.mkEnableOption "tools for Unison development";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which package of Unison to use";
      default = pkgs.unison-ucm;
      defaultText = lib.literalExpression "pkgs.unison-ucm";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "unison";
      meta = {
        name = "Unison";
        description = "Unison language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "unison";
      };
      enablePath = "languages.unison.enable";
      configPath = "languages.unison";
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
