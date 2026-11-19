# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.opentofu;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:opentofu";

  options.stackpanel.languages.opentofu = {
    enable = lib.mkEnableOption "tools for OpenTofu development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.opentofu;
      defaultText = lib.literalExpression "pkgs.opentofu";
      description = "The OpenTofu package to use.";
    };

    lsp = {
      enable = lib.mkEnableOption "OpenTofu Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.tofu-ls;
        defaultText = lib.literalExpression "pkgs.tofu-ls";
        description = "The OpenTofu language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "opentofu";
      meta = {
        name = "OpenTofu";
        description = "OpenTofu language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "opentofu";
      };
      enablePath = "languages.opentofu.enable";
      configPath = "languages.opentofu";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.git-hooks.hooks = {
          terraform-format.package = lib.mkOverride 500 cfg.package;
          terraform-validate.package = lib.mkOverride 500 cfg.package;
        };

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
