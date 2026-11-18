# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.cplusplus;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:cplusplus";

  options.stackpanel.languages.cplusplus = {
    enable = lib.mkEnableOption "tools for C++ development";

    lsp = {
      enable = lib.mkEnableOption "C++ Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ccls;
        defaultText = lib.literalExpression "pkgs.ccls";
        description = "The C++ language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "cplusplus";
      meta = {
        name = "C++";
        description = "C++ language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "cplusplus";
      };
      enablePath = "languages.cplusplus.enable";
      configPath = "languages.cplusplus";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          clang-tools
          cmake
          clang
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
