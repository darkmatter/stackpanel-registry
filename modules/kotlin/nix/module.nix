# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.kotlin;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:kotlin";

  options.stackpanel.languages.kotlin = {
    enable = lib.mkEnableOption "tools for Kotlin development";
    lsp = {
      enable = lib.mkEnableOption "Kotlin Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kotlin-language-server;
        defaultText = lib.literalExpression "pkgs.kotlin-language-server";
        description = "The Kotlin language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "kotlin";
      meta = {
        name = "Kotlin";
        description = "Kotlin language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "kotlin";
      };
      enablePath = "languages.kotlin.enable";
      configPath = "languages.kotlin";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          kotlin
          gradle
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
