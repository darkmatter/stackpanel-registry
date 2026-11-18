# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.stackpanel.languages.texlive;

  getPackage = ps: name: ps.${name} or (throw "No such texlive package ${name}");
  package = cfg.base.withPackages (ps: builtins.map (getPackage ps) cfg.packages);
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:texlive";

  options.stackpanel.languages.texlive = {
    enable = lib.mkEnableOption "TeX Live";
    base = lib.mkOption {
      default = pkgs.texliveSmall;
      defaultText = lib.literalExpression "pkgs.texliveSmall";
      example = lib.literalExpression "pkgs.texliveBasic";
      description = "TeX Live package set to use";
    };
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "algorithms"
        "latexmk"
      ];
      description = "Extra packages to add to the base TeX Live set";
    };

    lsp = {
      enable = lib.mkEnableOption "TeX Live Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.texlab;
        defaultText = lib.literalExpression "pkgs.texlab";
        description = "The TeX Live language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "texlive";
      meta = {
        name = "TeX Live";
        description = "TeX Live language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "texlive";
      };
      enablePath = "languages.texlive.enable";
      configPath = "languages.texlive";
      features.packages = true;
      packages = _: [ package ] ++ lib.optional cfg.lsp.enable cfg.lsp.package;
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
