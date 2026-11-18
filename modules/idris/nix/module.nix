# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.idris;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:idris";

  options.stackpanel.languages.idris = {
    enable = lib.mkEnableOption "tools for Idris development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.idris2;
      defaultText = lib.literalExpression "pkgs.idris2";
      description = ''
        The Idris package to use.
      '';
      example = lib.literalExpression "pkgs.idris";
    };

    lsp = {
      enable = lib.mkEnableOption "Idris Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.idris2Packages.idris2Lsp;
        defaultText = lib.literalExpression "pkgs.idris2Packages.idris2Lsp";
        description = "The Idris language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "idris";
      meta = {
        name = "Idris";
        description = "Idris language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "idris";
      };
      enablePath = "languages.idris.enable";
      configPath = "languages.idris";
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
