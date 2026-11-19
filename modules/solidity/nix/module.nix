# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{ foundry }:
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.solidity;

  foundryPackage = (import (foundry + "/foundry-bin") { inherit pkgs; }).overrideAttrs (old: {
    # Recent Foundry binaries link libudev, but foundry.nix does not yet add
    # it to auto-patchelf's search path.
    nativeBuildInputs =
      (old.nativeBuildInputs or [ ]) ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.udev;
  });

  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:solidity";

  options.stackpanel.languages.solidity = {
    enable = lib.mkEnableOption "tools for Solidity development";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which compiler of Solidity to use.";
      default = pkgs.solc;
      defaultText = lib.literalExpression "pkgs.solc";
    };

    foundry = {
      enable = lib.mkEnableOption "install Foundry";

      package = lib.mkOption {
        type = lib.types.package;
        description = "Which Foundry package to use.";
        default = foundryPackage;
        defaultText = lib.literalExpression "the locked Foundry binary package";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "solidity";
      meta = {
        name = "Solidity";
        description = "Solidity language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "solidity";
      };
      enablePath = "languages.solidity.enable";
      configPath = "languages.solidity";
      features.packages = true;
      packages = _: [ cfg.package ] ++ lib.optional cfg.foundry.enable (cfg.foundry.package);
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
