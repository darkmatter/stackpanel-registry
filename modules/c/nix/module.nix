# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.c;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:c";

  options.stackpanel.languages.c = {
    enable = lib.mkEnableOption "tools for C development";

    lsp = {
      enable = lib.mkEnableOption "C Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ccls;
        defaultText = lib.literalExpression "pkgs.ccls";
        description = "The C language server package to use.";
      };
    };

    debugger = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default =
        if pkgs.stdenv.hostPlatform.isDarwin then
          pkgs.lldb
        else if lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.gdb then
          pkgs.gdb
        else
          null;
      defaultText = lib.literalExpression "pkgs.gdb";
      description = ''
        An optional debugger package to use with c.
        The default is `lldb` on macOS, `gdb` on Linux (if supported), or `null` otherwise.
      '';
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "c";
      meta = {
        name = "C";
        description = "C language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "c";
      };
      enablePath = "languages.c.enable";
      configPath = "languages.c";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          clang-tools
          stdenv
          gnumake
          pkg-config
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package
        ++ lib.optional (cfg.debugger != null) cfg.debugger
        ++ lib.optional (
          lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.valgrind && !pkgs.valgrind.meta.broken
        ) pkgs.valgrind;
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
