# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.nix;
  cachix = lib.getBin config.cachix.package;

  # a bit of indirection to prevent mkShell from overriding the installed Nix
  vulnix = pkgs.buildEnv {
    name = "vulnix";
    paths = [ pkgs.vulnix ];
    pathsToLink = [ "/bin" ];
  };
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:nix";

  options.stackpanel.languages.nix = {
    enable = lib.mkEnableOption "tools for Nix development";

    lsp = {
      enable = lib.mkEnableOption "Nix Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nixd;
        defaultText = lib.literalExpression "pkgs.nixd";
        description = "The Nix language server package to use.";
      };
    };
  };

  options.cachix = {
    enable = lib.mkEnableOption "Cachix" // {
      default = false;
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cachix;
      description = "Cachix package, read by the copied Nix language module.";
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "nix";
      meta = {
        name = "Nix";
        description = "Nix language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "nix";
      };
      enablePath = "languages.nix.enable";
      configPath = "languages.nix";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          statix
          deadnix
          vulnix
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package
        ++ lib.optional config.cachix.enable cachix;
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
