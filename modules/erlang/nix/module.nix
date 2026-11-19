# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.erlang;
  # rebar3 must be compiled with the selected Erlang so its BEAM files load on the user's OTP version.
  # `pkgs.beamPackages` supports `overrideScope` on recent nixpkgs and `extend` on nixpkgs 25.05; try both.
  beamPackagesForErlang =
    erlang:
    if pkgs.beamPackages ? overrideScope then
      pkgs.beamPackages.overrideScope (final: prev: { inherit erlang; })
    else
      pkgs.beamPackages.extend (final: prev: { inherit erlang; });
  rebar3 = (beamPackagesForErlang cfg.package).rebar3;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:erlang";

  options.stackpanel.languages.erlang = {
    enable = lib.mkEnableOption "tools for Erlang development";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which Erlang package to use.";
      default = pkgs.beamPackages.erlang;
      defaultText = lib.literalExpression "pkgs.beamPackages.erlang";
    };

    lsp = {
      enable = lib.mkEnableOption "Erlang Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.erlang-language-platform;
        defaultText = lib.literalExpression "pkgs.erlang-language-platform";
        description = "The Erlang language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "erlang";
      meta = {
        name = "Erlang";
        description = "Erlang language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "erlang";
      };
      enablePath = "languages.erlang.enable";
      configPath = "languages.erlang";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
          rebar3
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
