# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.elixir;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:elixir";

  options.stackpanel.languages.elixir = {
    enable = lib.mkEnableOption "tools for Elixir development";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which Elixir package to use.";
      default = pkgs.beamPackages.elixir;
      defaultText = lib.literalExpression "pkgs.beamPackages.elixir";
    };

    lsp = {
      enable = lib.mkEnableOption "Elixir Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.beamPackages.elixir-ls;
        defaultText = lib.literalExpression "pkgs.beamPackages.elixir-ls";
        description = "The Elixir language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "elixir";
      meta = {
        name = "Elixir";
        description = "Elixir language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "elixir";
      };
      enablePath = "languages.elixir.enable";
      configPath = "languages.elixir";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.git-hooks.hooks = {
          credo.package = cfg.package;
          dialyzer.package = cfg.package;
          mix-format.package = cfg.package;
          mix-test.package = cfg.package;
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
