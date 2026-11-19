# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.standardml;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:standardml";

  options.stackpanel.languages.standardml = {
    enable = lib.mkEnableOption "tools for Standard ML development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mlton;
      defaultText = lib.literalExpression "pkgs.mlton";
      description = ''
        The Standard ML package to use.
      '';
    };

    lsp = {
      enable = lib.mkEnableOption "Standard ML Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.millet;
        defaultText = lib.literalExpression "pkgs.millet";
        description = "The Standard ML language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "standardml";
      meta = {
        name = "Standard ML";
        description = "Standard ML language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "standardml";
      };
      enablePath = "languages.standardml.enable";
      configPath = "languages.standardml";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
          pkgs.smlfmt
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
