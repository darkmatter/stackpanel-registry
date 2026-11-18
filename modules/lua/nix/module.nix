# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.lua;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:lua";

  options.stackpanel.languages.lua = {
    enable = lib.mkEnableOption "tools for Lua development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.lua;
      defaultText = lib.literalExpression "pkgs.lua";
      description = "The Lua package to use.";
    };

    lsp = {
      enable = lib.mkEnableOption "Lua Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.lua-language-server;
        defaultText = lib.literalExpression "pkgs.lua-language-server";
        description = "The Lua language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "lua";
      meta = {
        name = "Lua";
        description = "Lua language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "lua";
      };
      enablePath = "languages.lua.enable";
      configPath = "languages.lua";
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
