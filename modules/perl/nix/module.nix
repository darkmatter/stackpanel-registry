# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.perl;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:perl";

  options.stackpanel.languages.perl = {
    enable = lib.mkEnableOption "tools for Perl development";
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Perl packages to include";
      default = [ ];
      example = [ "Mojolicious" ];
    };

    lsp = {
      enable = lib.mkEnableOption "Perl Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.perlnavigator;
        defaultText = lib.literalExpression "pkgs.perlnavigator";
        description = "The Perl language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "perl";
      meta = {
        name = "Perl";
        description = "Perl language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "perl";
      };
      enablePath = "languages.perl.enable";
      configPath = "languages.perl";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          (perl.withPackages (
            p: (with builtins; map (pkg: p.${replaceStrings [ "::" ] [ "" ] pkg}) cfg.packages)
          ))
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
