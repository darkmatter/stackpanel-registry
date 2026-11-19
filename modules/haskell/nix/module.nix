# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.haskell;

  # Wrapper for stack that configures it to use devenv's GHC
  stackWrapper =
    pkgs.runCommand "stack-wrapper"
      {
        buildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${cfg.stack.package}/bin/stack $out/bin/stack \
          ${lib.concatMapStringsSep " \\\n      " (arg: "--add-flags \"${arg}\"") cfg.stack.args}
      '';
  # ghc.version with removed dots
  ghcVersion = lib.replaceStrings [ "." ] [ "" ] cfg.package.version;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:haskell";

  options.stackpanel.languages.haskell = {
    enable = lib.mkEnableOption "tools for Haskell development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ghc;
      defaultText = lib.literalExpression "pkgs.ghc";
      description = ''
        Haskell compiler to use.
      '';
    };

    lsp = {
      enable = lib.mkEnableOption "Haskell Language Server" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.haskell-language-server.override {
          supportedGhcVersions = [ ghcVersion ];
        };
        defaultText = lib.literalExpression "pkgs.haskell-language-server";
        description = "The Haskell language server package to use.";
      };
    };

    stack = {
      enable = lib.mkEnableOption "Stack" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.stack;
        defaultText = lib.literalExpression "pkgs.stack";
        description = ''
          Haskell stack package to use.
        '';
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--no-nix"
          "--system-ghc"
          "--no-install-ghc"
        ];
        defaultText = lib.literalExpression ''[ "--no-nix" "--system-ghc" "--no-install-ghc" ]'';
        description = ''
          Additional arguments to pass to stack.
          By default, stack is configured to use devenv's GHC installation.
        '';
      };
    };

    cabal = {
      enable = lib.mkEnableOption "Cabal" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.cabal-install;
        defaultText = lib.literalExpression "pkgs.cabal-install";
        description = ''
          Cabal package to use.
        '';
      };
    };
  };

  imports = [
    (lib.mkRenamedOptionModule
      [ "stackpanel" "languages" "haskell" "languageServer" ]
      [ "stackpanel" "languages" "haskell" "lsp" "package" ]
    )
    (lib.stackpanel.mkModule {
      name = "haskell";
      meta = {
        name = "Haskell";
        description = "Haskell language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "haskell";
      };
      enablePath = "languages.haskell.enable";
      configPath = "languages.haskell";
      features.packages = true;
      packages =
        _:
        with pkgs;
        [
          cfg.package
          zlib
          hpack
        ]
        ++ (lib.optional cfg.lsp.enable cfg.lsp.package)
        ++ (lib.optional cfg.cabal.enable cfg.cabal.package)
        ++ (lib.optional cfg.stack.enable stackWrapper);
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
