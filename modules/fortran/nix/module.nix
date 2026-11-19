# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.fortran;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:fortran";

  options.stackpanel.languages.fortran = {
    enable = lib.mkEnableOption "tools for Fortran Development.";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gfortran;
      defaultText = lib.literalExpression "pkgs.gfortran";
      description = "The Fortran package to use.";
    };

    lsp = {
      enable = lib.mkEnableOption "Fortran Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.fortls;
        defaultText = lib.literalExpression "pkgs.fortls";
        description = "The Fortran language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "fortran";
      meta = {
        name = "Fortran";
        description = "Fortran language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "fortran";
      };
      enablePath = "languages.fortran.enable";
      configPath = "languages.fortran";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          cfg.package
          fortran-fpm
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
