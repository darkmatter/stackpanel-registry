# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.java;
  mavenArgs = lib.functionArgs pkgs.maven.override;
  mavenPackage =
    if builtins.hasAttr "jdk" mavenArgs then
      # ensure backwards compatibility when using pkgs from before this commit: https://github.com/NixOS/nixpkgs/commit/ea0bc3224593ddf7ac6c702c7acb6c89cf188f0f
      pkgs.maven.override { jdk = cfg.jdk.package; }
    else
      pkgs.maven.override { jdk_headless = cfg.jdk.package; };
  inherit (lib)
    types
    mkEnableOption
    mkOption
    mkDefault
    optional
    literalExpression
    ;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:java";

  options.stackpanel.languages.java = {
    enable = mkEnableOption "tools for Java development";
    jdk.package = mkOption {
      type = types.package;
      example = literalExpression "pkgs.jdk8";
      default = pkgs.jdk;
      defaultText = literalExpression "pkgs.jdk";
      description = ''
        The JDK package to use.
        This will also become available as `JAVA_HOME`.
      '';
    };
    maven = {
      enable = mkEnableOption "maven";
      package = mkOption {
        type = types.package;
        defaultText = literalExpression "pkgs.maven.override { jdk_headless = cfg.jdk.package; }";
        description = ''
          The Maven package to use.
          The Maven package by default inherits the JDK from `stackpanel.languages.java.jdk.package`.
        '';
      };
    };
    gradle = {
      enable = mkEnableOption "gradle";
      package = mkOption {
        type = types.package;
        defaultText = literalExpression "pkgs.gradle.override { java = cfg.jdk.package; }";
        description = ''
          The Gradle package to use.
          The Gradle package by default inherits the JDK from `stackpanel.languages.java.jdk.package`.
        '';
      };
    };
    lsp = {
      enable = mkEnableOption "Java Language Server" // {
        default = true;
      };
      package = mkOption {
        type = types.package;
        defaultText = literalExpression "pkgs.jdt-language-server.override { jdk = cfg.jdk.package; }";
        description = ''
          The Java language server package to use.
          The Java language server package by default inherits the JDK from `stackpanel.languages.java.jdk.package`.
        '';
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "java";
      meta = {
        name = "Java";
        description = "Java language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "java";
      };
      enablePath = "languages.java.enable";
      configPath = "languages.java";
      features.packages = true;
      packages =
        _:
        [ cfg.jdk.package ]
        ++ (optional cfg.maven.enable cfg.maven.package)
        ++ (optional cfg.gradle.enable cfg.gradle.package)
        ++ (optional cfg.lsp.enable cfg.lsp.package);
      config = _: {
        stackpanel.languages.java.maven.package = mkDefault mavenPackage;

        stackpanel.languages.java.gradle.package = mkDefault (
          pkgs.gradle.override { java = cfg.jdk.package; }
        );

        stackpanel.languages.java.lsp.package = mkDefault (
          pkgs.jdt-language-server.override { jdk = cfg.jdk.package; }
        );

        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
          JAVA_HOME = cfg.jdk.package.home;
        };
      };
    })
  ];
}
