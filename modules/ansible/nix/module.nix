# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.ansible;
  # ansible-language-server may not be available in all nixpkgs versions
  hasLsp = pkgs ? ansible-language-server && (builtins.tryEval pkgs.ansible-language-server).success;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:ansible";

  options.stackpanel.languages.ansible = {
    enable = lib.mkEnableOption "tools for Ansible development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ansible;
      defaultText = lib.literalExpression "pkgs.ansible";
      description = "The Ansible package to use.";
    };

    lsp = {
      enable = lib.mkEnableOption "Ansible Language Server" // {
        default = hasLsp;
      };

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = if hasLsp then pkgs.ansible-language-server else null;
        defaultText = lib.literalExpression "pkgs.ansible-language-server";
        description = "The Ansible language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "ansible";
      meta = {
        name = "Ansible";
        description = "Ansible language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "ansible";
      };
      enablePath = "languages.ansible.enable";
      configPath = "languages.ansible";
      features.packages = true;
      packages =
        _:
        [
          pkgs.ansible-lint
          cfg.package
        ]
        ++ lib.optional (cfg.lsp.enable && cfg.lsp.package != null) cfg.lsp.package;
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
