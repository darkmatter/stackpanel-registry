# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.crystal;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:crystal";

  options.stackpanel.languages.crystal = {
    enable = lib.mkEnableOption "Enable tools for Crystal development.";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.crystal;
      defaultText = lib.literalExpression "pkgs.crystal";
      description = "The Crystal package to use.";
    };

    shards = lib.mkOption {
      type = lib.types.submodule {
        options.package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.shards;
          defaultText = lib.literalExpression "pkgs.shards";
          description = "The Shards package to use.";
        };
      };
      description = "Configuration for shards";
      default = { };
    };

    lsp = {
      enable = lib.mkEnableOption "Crystal Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.crystalline;
        defaultText = lib.literalExpression "pkgs.crystalline";
        description = "The Crystal language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "crystal";
      meta = {
        name = "Crystal";
        description = "Crystal language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "crystal";
      };
      enablePath = "languages.crystal.enable";
      configPath = "languages.crystal";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
          cfg.shards.package
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.languages.c.enable = lib.mkDefault true;

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
