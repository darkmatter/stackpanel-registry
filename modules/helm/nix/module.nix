# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.helm;

  # Resolve plugin names to packages
  resolvedPlugins = builtins.map (
    name: pkgs.kubernetes-helmPlugins.${name} or (throw "Unknown Helm plugin: ${name}")
  ) cfg.plugins;

  # https://github.com/NixOS/nixpkgs/issues/217768
  helm-plugins-dir = pkgs.symlinkJoin {
    name = "helm-plugins";
    paths = resolvedPlugins;
  };
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:helm";

  options.stackpanel.languages.helm = {
    enable = lib.mkEnableOption "tools for Helm development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes-helm;
      defaultText = lib.literalExpression "pkgs.kubernetes-helm";
      description = "The Helm package to use.";
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "helm-secrets"
        "helm-diff"
        "helm-unittest"
      ];
      description = ''
        List of Helm plugin names to include from pkgs.kubernetes-helmPlugins.

        They will be symlinked into one directory and exposed via HELM_PLUGINS.
      '';
    };

    lsp = {
      enable = lib.mkEnableOption "Helm Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.helm-ls;
        defaultText = lib.literalExpression "pkgs.helm-ls";
        description = "The Helm language server package to use.";
      };
    };
  };

  imports = [
    (lib.mkRenamedOptionModule
      [ "stackpanel" "languages" "helm" "languageServer" "enable" ]
      [ "stackpanel" "languages" "helm" "lsp" "enable" ]
    )
    (lib.mkRenamedOptionModule
      [ "stackpanel" "languages" "helm" "languageServer" "package" ]
      [ "stackpanel" "languages" "helm" "lsp" "package" ]
    )
    (lib.stackpanel.mkModule {
      name = "helm";
      meta = {
        name = "Helm";
        description = "Helm language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "helm";
      };
      enablePath = "languages.helm.enable";
      configPath = "languages.helm";
      features.packages = true;
      packages = _: [ cfg.package ] ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
          HELM_PLUGINS = "${helm-plugins-dir}";
        };
      };
    })
  ];
}
