# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.elm;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:elm";

  options.stackpanel.languages.elm = {
    enable = lib.mkEnableOption "tools for Elm development";

    lsp = {
      enable = lib.mkEnableOption "Elm Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.elmPackages.elm-language-server;
        defaultText = lib.literalExpression "pkgs.elmPackages.elm-language-server";
        description = "The Elm language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "elm";
      meta = {
        name = "Elm";
        description = "Elm language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "elm";
      };
      enablePath = "languages.elm.enable";
      configPath = "languages.elm";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          elmPackages.elm
          elmPackages.elm-format
          elmPackages.elm-test
          elm2nix
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
