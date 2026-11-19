# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.vala;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:vala";

  options.stackpanel.languages.vala = {
    enable = lib.mkEnableOption "tools for Vala development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vala;
      defaultText = lib.literalExpression "pkgs.vala";
      description = "The Vala package to use.";
      example = lib.literalExpression "pkgs.vala_0_54";
    };

    lsp = {
      enable = lib.mkEnableOption "Vala Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.vala-language-server;
        defaultText = lib.literalExpression "pkgs.vala-language-server";
        description = "The Vala language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "vala";
      meta = {
        name = "Vala";
        description = "Vala language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "vala";
      };
      enablePath = "languages.vala.enable";
      configPath = "languages.vala";
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
