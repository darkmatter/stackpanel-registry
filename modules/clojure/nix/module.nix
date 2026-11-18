# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.clojure;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:clojure";

  options.stackpanel.languages.clojure = {
    enable = lib.mkEnableOption "tools for Clojure development";

    lsp = {
      enable = lib.mkEnableOption "Clojure Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.clojure-lsp;
        defaultText = lib.literalExpression "pkgs.clojure-lsp";
        description = "The Clojure language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "clojure";
      meta = {
        name = "Clojure";
        description = "Clojure language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "clojure";
      };
      enablePath = "languages.clojure.enable";
      configPath = "languages.clojure";
      features.packages = true;
      requires = [ "java" ];
      packages =
        _:
        [
          (pkgs.clojure.override {
            jdk = config.stackpanel.languages.java.jdk.package;
          })
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.languages.java.enable = true;

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
