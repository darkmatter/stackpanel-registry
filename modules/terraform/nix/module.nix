# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{ nixpkgs-terraform }:
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.terraform;

  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:terraform";

  options.stackpanel.languages.terraform = {
    enable = lib.mkEnableOption "tools for Terraform development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.terraform;
      defaultText = lib.literalExpression "pkgs.terraform";
      description = "The Terraform package to use.";
    };

    version = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The Terraform version to use.
        This automatically sets the `stackpanel.languages.terraform.package` using [nixpkgs-terraform](https://github.com/stackbuilders/nixpkgs-terraform).
      '';
      example = "1.5.0 or 1.6.2";
    };

    lsp = {
      enable = lib.mkEnableOption "Terraform Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.terraform-ls;
        defaultText = lib.literalExpression "pkgs.terraform-ls";
        description = "The Terraform language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "terraform";
      meta = {
        name = "Terraform";
        description = "Terraform language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "terraform";
      };
      enablePath = "languages.terraform.enable";
      configPath = "languages.terraform";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
          pkgs.tfsec
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.git-hooks.hooks = {
          terraform-format.package = lib.mkOverride 500 cfg.package;
          terraform-validate.package = lib.mkOverride 500 cfg.package;
        };

        stackpanel.languages.terraform.package = lib.mkIf (cfg.version != null) (
          let
            terraform-pkgs = nixpkgs-terraform.packages.${pkgs.stdenv.hostPlatform.system};
          in
          terraform-pkgs."terraform-${cfg.version}" or (throw
            "Unsupported Terraform version '${cfg.version}' in the locked terraform/nixpkgs-terraform input.")
        );

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
