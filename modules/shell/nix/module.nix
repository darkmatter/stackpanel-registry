# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.shell;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:shell";

  options.stackpanel.languages.shell = {
    enable = lib.mkEnableOption "tools for shell development";

    lsp = {
      enable = lib.mkEnableOption "Shell Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.bash-language-server;
        defaultText = lib.literalExpression "pkgs.bash-language-server";
        description = "The Shell language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "shell";
      meta = {
        name = "Shell";
        description = "Shell language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "shell";
      };
      enablePath = "languages.shell.enable";
      configPath = "languages.shell";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          (pkgs.bats.withLibraries (p: [
            p.bats-assert
            p.bats-file
            p.bats-support
          ]))
          shellcheck
          shfmt
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
