# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{ nixpkgs-ruby }:
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.ruby;

  # Whether using a custom Ruby version (from nixpkgs-ruby)
  usingCustomRuby = cfg.version != null || cfg.versionFile != null;
  system = pkgs.stdenv.hostPlatform.system;
  selectedRuby =
    if cfg.version != null then
      nixpkgs-ruby.packages.${system}."ruby-${cfg.version}"
    else
      nixpkgs-ruby.lib.packageFromRubyVersionFile { inherit system; file = cfg.versionFile; };

  # Wrap a Ruby gem package to only expose binaries, without propagating
  # gem dependencies to the environment. The gem's own wrapper script
  # handles its dependencies, so propagation just causes conflicts.
  wrapGemBin =
    pkg:
    pkgs.runCommand "${pkg.name}-bin" { } ''
      mkdir -p $out/bin
      for f in ${pkg}/bin/*; do
        ln -s "$f" "$out/bin/$(basename "$f")"
      done
    '';

  # Build solargraph LSP with the user's Ruby using bundlerEnv.
  # This ensures native extensions are compiled against the correct Ruby.
  lspEnv = pkgs.bundlerEnv {
    name = "solargraph-lsp";
    ruby = cfg.package;
    gemdir = ./ruby-lsp;
  };

  lspPackage = if usingCustomRuby then cfg.lsp.package else wrapGemBin cfg.lsp.package;

  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];

  assertions = [
    {
      assertion = cfg.version == null || cfg.versionFile == null;
      message = ''
        `stackpanel.languages.ruby.version` and `stackpanel.languages.ruby.versionFile` are both set.
        Only one of the two may be set. Remove one of the two options.
      '';
    }
  ];
  failed = builtins.filter (check: !check.assertion) assertions;

  toolchain =
    lib.optional cfg.bundler.enable cfg.bundler.package
    ++ [
      cfg.package
    ]
    ++ lib.optional cfg.lsp.enable lspPackage;
in
{
  key = "stackpanel-registry:ruby";

  options.stackpanel.languages.ruby = {
    enable = lib.mkEnableOption "tools for Ruby development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ruby;
      defaultText = lib.literalExpression "pkgs.ruby";
      description = "The Ruby package to use.";
    };

    version = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The Ruby version to use.
        This automatically sets the `stackpanel.languages.ruby.package` using [nixpkgs-ruby](https://github.com/bobvanderlinden/nixpkgs-ruby).
      '';
      example = "3.2.1";
    };

    versionFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        The .ruby-version file path to extract the Ruby version from.
        This automatically sets the `stackpanel.languages.ruby.package` using [nixpkgs-ruby](https://github.com/bobvanderlinden/nixpkgs-ruby).
        When the `.ruby-version` file exists in the same directory as the project configuration, you can use:

        ```nix
        stackpanel.languages.ruby.versionFile = ./.ruby-version;
        ```
      '';
      example = lib.literalExpression ''
        ./.ruby-version
      '';
    };

    bundler = {
      enable = lib.mkEnableOption "bundler";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.bundler.override { ruby = cfg.package; };
        defaultText = lib.literalExpression "pkgs.bundler.override { ruby = cfg.package; }";
        description = "The bundler package to use.";
      };
    };

    documentation = {
      enable = lib.mkEnableOption "documentation support for Ruby packages";
    };

    lsp = {
      enable = lib.mkEnableOption "Ruby Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = if usingCustomRuby then lspEnv else pkgs.solargraph.override { ruby = cfg.package; };
        defaultText = lib.literalMD "Solargraph from the bundled gemset for a selected Ruby; otherwise nixpkgs Solargraph.";
        description = ''
          The Ruby language server package to use. With `version` or `versionFile`,
          the bundled Solargraph gems are built against the selected interpreter.
          For legacy Rubies incompatible with these gems, select a compatible
          LSP package or disable `lsp.enable`.
        '';
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "ruby";
      meta = {
        name = "Ruby";
        description = "Ruby language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "ruby";
      };
      enablePath = "languages.ruby.enable";
      configPath = "languages.ruby";
      features.packages = true;
      packages =
        _:
        if failed == [ ] then
          toolchain
        else
          throw (lib.concatMapStringsSep "\n" (check: check.message) failed);
      config = _: {
        stackpanel.languages.c.enable = lib.mkDefault true;

        stackpanel.languages.ruby.bundler.enable = lib.mkDefault true;

        stackpanel.languages.ruby.package = lib.mkIf usingCustomRuby (
          selectedRuby.override {
            docSupport = cfg.documentation.enable;
            # Upstream disallows parallel documentation builds before Ruby 3.4.
            parallelBuild = !cfg.documentation.enable || lib.versionAtLeast (toString selectedRuby.version) "3.4.0";
          }
        );

        stackpanel.devshell.hooks.main = [
          (
            let
              libdir = cfg.package.version.libDir;
            in
            ''
              export RUBYLIB="$DEVENV_PROFILE/${libdir}:$DEVENV_PROFILE/lib/ruby/site_ruby:$DEVENV_PROFILE/lib/ruby/site_ruby/${libdir}:$DEVENV_PROFILE/lib/ruby/site_ruby/${libdir}/${pkgs.stdenv.system}:''${RUBYLIB:-}"
              export GEM_PATH="$GEM_HOME/gems:''${GEM_PATH:-}"
              export PATH="$GEM_HOME/bin:$PATH"
            ''
          )
        ];

        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
          BUNDLE_PATH = config.stackpanel.devshell.env.DEVENV_STATE + "/.bundle";
          GEM_HOME = "${config.stackpanel.devshell.env.BUNDLE_PATH}/${cfg.package.rubyEngine}/${cfg.package.version.libDir}";
        };
      };
    })
  ];
}
