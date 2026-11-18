# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{ defaultOverlay }:
{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.purescript;

  purescript-overlay = inputs.purescript-overlay or defaultOverlay;

  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:purescript";

  options.stackpanel.languages.purescript = {
    enable = lib.mkEnableOption "tools for PureScript development";

    package = lib.mkOption {
      type = lib.types.package;
      default = purescript-overlay.packages.${pkgs.stdenv.system}.purs;
      defaultText = lib.literalExpression "purescript-overlay.packages.\${pkgs.stdenv.system}.purs";
      description = ''
        The PureScript compiler package to use.
        Uses [purescript-overlay](https://github.com/thomashoneyman/purescript-overlay) by default.
      '';
    };

    spago = {
      enable = lib.mkEnableOption "Spago package manager" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = purescript-overlay.packages.${pkgs.stdenv.system}.spago;
        defaultText = lib.literalExpression "purescript-overlay.packages.\${pkgs.stdenv.system}.spago";
        description = ''
          The Spago package manager to use.
          Uses [purescript-overlay](https://github.com/thomashoneyman/purescript-overlay) by default.
        '';
      };
    };

    lsp = {
      enable = lib.mkEnableOption "PureScript Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = purescript-overlay.packages.${pkgs.stdenv.system}.purescript-language-server;
        defaultText = lib.literalExpression "purescript-overlay.packages.\${pkgs.stdenv.system}.purescript-language-server";
        description = ''
          The PureScript language server package to use.
          Uses [purescript-overlay](https://github.com/thomashoneyman/purescript-overlay) by default.
        '';
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "purescript";
      meta = {
        name = "PureScript";
        description = "PureScript language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "purescript";
      };
      enablePath = "languages.purescript.enable";
      configPath = "languages.purescript";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
        ]
        ++ lib.optional cfg.spago.enable cfg.spago.package
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
