# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.ocaml;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:ocaml";

  options.stackpanel.languages.ocaml = {
    enable = lib.mkEnableOption "tools for OCaml development";

    packages = lib.mkOption {
      type = lib.types.attrs;
      description = "The package set of OCaml to use";
      default = pkgs.ocaml-ng.ocamlPackages;
      defaultText = lib.literalExpression "pkgs.ocaml-ng.ocamlPackages_4_12";
    };

    lsp = {
      enable = lib.mkEnableOption "OCaml Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ocamlPackages.ocaml-lsp;
        defaultText = lib.literalExpression "pkgs.ocamlPackages.ocaml-lsp";
        description = "The OCaml language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "ocaml";
      meta = {
        name = "OCaml";
        description = "OCaml language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "ocaml";
      };
      enablePath = "languages.ocaml.enable";
      configPath = "languages.ocaml";
      features.packages = true;
      packages =
        _:
        [
          cfg.packages.ocaml
          cfg.packages.dune_3
          cfg.packages.merlin
          cfg.packages.utop
          cfg.packages.odoc
          cfg.packages.ocp-indent
          cfg.packages.findlib
          pkgs.ocamlformat
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
