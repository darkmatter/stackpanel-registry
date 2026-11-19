# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.odin;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:odin";

  options.stackpanel.languages.odin = {
    enable = lib.mkEnableOption "tools for Odin Language";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.odin;
      defaultText = lib.literalExpression "pkgs.odin";
      description = "The odin package to use.";
    };

    debugger = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = if lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.gdb then pkgs.gdb else null;
      defaultText = lib.literalExpression "pkgs.gdb";
      description = ''
        An optional debugger package to use with odin.
        The default is `gdb`, if supported on the current system.
      '';
    };

    lsp = {
      enable = lib.mkEnableOption "Odin Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ols;
        defaultText = lib.literalExpression "pkgs.ols";
        description = "The Odin language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "odin";
      meta = {
        name = "Odin";
        description = "Odin language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "odin";
      };
      enablePath = "languages.odin.enable";
      configPath = "languages.odin";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          nasm
          clang
          gnumake
          cfg.package
        ]
        ++ lib.optional (cfg.debugger != null) cfg.debugger
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
