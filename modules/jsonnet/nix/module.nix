# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.jsonnet;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:jsonnet";

  options.stackpanel.languages.jsonnet = {
    enable = lib.mkEnableOption "tools for jsonnet development";

    lsp = {
      enable = lib.mkEnableOption "Jsonnet Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.jsonnet-language-server;
        defaultText = lib.literalExpression "pkgs.jsonnet-language-server";
        description = "The Jsonnet language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "jsonnet";
      meta = {
        name = "Jsonnet";
        description = "Jsonnet language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "jsonnet";
      };
      enablePath = "languages.jsonnet.enable";
      configPath = "languages.jsonnet";
      features.packages = true;
      packages =
        _:
        [
          pkgs.go-jsonnet
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
