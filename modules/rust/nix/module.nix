{
  rust-overlay,
  crane,
  crate2nix,
}:
{
  config,
  options,
  lib,
  pkgs,
  self,
  isGlobalEval ? false,
  ...
}:
let
  stack = config.stackpanel;
  cfg = stack.languages.rust;
  fields = import ./fields.nix lib.stackpanel.spField;
  apps = lib.filterAttrs (_: app: app.rust.enable) stack.apps;
  toolchain = import ./toolchain.nix {
    inherit
      lib
      pkgs
      cfg
      rust-overlay
      crate2nix
      ;
  };
  workspace = import ./workspace.nix {
    inherit
      lib
      pkgs
      stack
      cfg
      toolchain
      ;
  };
  buildApp = import ./build-app.nix {
    inherit
      lib
      pkgs
      crane
      workspace
      ;
    toolchain = cfg.toolchainPackage;
    projectRoot = stack.root;
  };
  # Both systemd and the image run the very same package that nix build
  # exposes, evaluated for the deployment target rather than the developer.
  containerBuilder =
    {
      appName,
      app,
      image,
      containerLib,
      ...
    }:
    assert lib.assertMsg (
      app != null && app.rust.enable
    ) "The Rust container builder requires an app with rust.enable = true";
    let
      linux = containerLib.pkgsLinux;
      # On Linux don't re-enter the very package set collecting this image.
      system = linux.stdenv.hostPlatform.system;
      package =
        if pkgs.stdenv.hostPlatform.system == system then
          stack.appBuildProviders.rust.${appName}
        else
          self.packages.${system}.${appName};
      appDir = linux.runCommand "${appName}-container-root" { } ''
        mkdir -p "$out/app"
        ln -s ${lib.getExe package} "$out/app/server"
      '';
    in
    containerLib.buildImage (
      image
      // {
        inherit appDir;
        defaultCommand = [ "/app/server" ];
      }
    );
in
{
  imports = [
    ./workspace-options.nix
    (lib.stackpanel.mkModule {
      name = "rust";
      meta = {
        name = "Rust";
        description = "Rust workspace toolchains, Cargo builds, containers and native systemd services.";
        category = "language";
        icon = "cog";
        version = "0.1.0";
      };
      source = {
        type = "flake-input";
        flakeInput = "rust";
      };
      tags = [
        "rust"
        "cargo"
        "runtime"
      ];
      features = {
        packages = true;
        files = true;
      };
      readme = builtins.readFile ../README.md;
      defaultEnable = cfg.enable;
      inherit (workspace) packages;
      appOptions.rust = fields;
      config =
        _:
        lib.mkMerge [
          {
            stackpanel.appRuntimes.rust = {
              label = "Rust";
              icon = "cog";
              module = "rust";
            };
            stackpanel.appModules = [
              ({ config, ... }: {
                config = lib.mkIf config.rust.enable {
                  container.type = lib.mkDefault "rust";
                  deployment.resolvedCommand = lib.mkDefault (
                    {
                      inputs,
                      pkgs,
                      name,
                      ...
                    }:
                    lib.getExe inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.${name}
                  );
                };
              })
            ];
            stackpanel.containerBuilders.rust = containerBuilder;
          }
          # Preserve the original language module's C integration if installed.
          # Without it the Rust shell still supplies the native compiler tools.
          (lib.optionalAttrs (!isGlobalEval && options.stackpanel.languages ? c.enable) {
            stackpanel.languages.c.enable = lib.mkDefault true;
          })
          (lib.optionalAttrs (!isGlobalEval) workspace.config)
          (lib.optionalAttrs (!isGlobalEval) {
            stackpanel.appBuildProviders.rust = lib.mapAttrs buildApp apps;
            stackpanel.panels.rust-runtime =
              (lib.stackpanel.panels.mkPanelFromSpFields {
                module = "rust";
                title = "Rust runtime";
                icon = "cog";
                optionPrefix = "rust";
                inherit fields apps;
              })
              // {
                slot = "app:runtime";
              };
          })
        ];
    })
  ];
}
