# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.nim;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:nim";

  options.stackpanel.languages.nim = {
    enable = lib.mkEnableOption "tools for Nim development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nim;
      defaultText = lib.literalExpression "pkgs.nim";
      description = "The Nim package to use.";
    };

    lsp = {
      enable = lib.mkEnableOption "Nim Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nimlangserver;
        defaultText = lib.literalExpression "pkgs.nimlangserver";
        description = "The Nim language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "nim";
      meta = {
        name = "Nim";
        description = "Nim language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "nim";
      };
      enablePath = "languages.nim.enable";
      configPath = "languages.nim";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
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
