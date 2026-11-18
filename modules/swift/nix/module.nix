# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.swift;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:swift";

  options.stackpanel.languages.swift = {
    enable = lib.mkEnableOption "tools for Swift development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.swift;
      defaultText = lib.literalExpression "pkgs.swift";
      description = ''
        The Swift package to use.
      '';
    };

    lsp = {
      enable = lib.mkEnableOption "Swift Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.sourcekit-lsp;
        defaultText = lib.literalExpression "pkgs.sourcekit-lsp";
        description = "The Swift language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "swift";
      meta = {
        name = "Swift";
        description = "Swift language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "swift";
      };
      enablePath = "languages.swift.enable";
      configPath = "languages.swift";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
          pkgs.clang
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
          CC = "${pkgs.clang}/bin/clang";
        };
      };
    })
  ];
}
