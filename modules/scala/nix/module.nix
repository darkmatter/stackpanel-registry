# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.stackpanel.languages.scala;
  java = config.stackpanel.languages.java;
  sbt = cfg.sbt.package;
  mill = cfg.mill.package;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:scala";

  options.stackpanel.languages.scala = {
    enable = lib.mkEnableOption "tools for Scala development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.scala_3;
      defaultText = lib.literalExpression "pkgs.scala_3";
      description = ''
        The Scala package to use.
      '';
    };

    sbt = with lib; {
      enable = mkEnableOption "sbt, the standard build tool for Scala";
      package = mkPackageOption pkgs "sbt" {
        default = "sbt";
        example = "sbt-with-scala-native";
      };
    };

    mill = with lib; {
      enable = mkEnableOption "mill, a simplified, fast build tool for Scala";
      package = mkPackageOption pkgs "mill" {
        default = "mill";
      };
    };

    lsp = {
      enable = lib.mkEnableOption "Scala Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.metals;
        defaultText = lib.literalExpression "pkgs.metals";
        description = "The Scala language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "scala";
      meta = {
        name = "Scala";
        description = "Scala language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "scala";
      };
      enablePath = "languages.scala.enable";
      configPath = "languages.scala";
      features.packages = true;
      requires = [ "java" ];
      packages =
        _:
        with pkgs;
        [
          (cfg.package.override { jre = java.jdk.package; })
          (coursier.override { jre = java.jdk.package; })
          (scalafmt.override { jre = java.jdk.package; })
        ]
        ++ lib.optional cfg.lsp.enable (
          # Metals is a language server: it runs in its own JVM and can still index and
          # build projects that target an older JDK via stackpanel.languages.java.jdk.package.
          # Only reuse the user's JDK for Metals when it's new enough; otherwise fall
          # back to pkgs.jdk (21 on both nixpkgs 25.05 and current unstable), which
          # satisfies Metals' Java 17+ requirement.
          cfg.lsp.package.override {
            jre = if lib.versionAtLeast java.jdk.package.version "17" then java.jdk.package else pkgs.jdk;
          }
        )
        ++ lib.optionals cfg.sbt.enable [
          (sbt.override (
            old:
            if (old ? "jre") then
              { jre = java.jdk.package; }
            else
              {
                sbt = old.sbt.override { jre = java.jdk.package; };
              }
          ))
        ]
        ++ lib.optionals cfg.mill.enable [
          (mill.override { jre = java.jdk.package; })
        ]
        ++ lib.optionals (lib.versionAtLeast java.jdk.package.version "17") [
          (scala-cli.override { jre = java.jdk.package; })
        ];
      config = _: {
        stackpanel.languages.java.enable = true;

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
