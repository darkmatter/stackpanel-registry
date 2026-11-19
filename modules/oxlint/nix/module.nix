{
  config,
  lib,
  pkgs,
  isGlobalEval ? false,
  ...
}@args:
let
  inherit (lib.stackpanel) mkModule spField panels;
  sp = config.stackpanel;
  fields = import ./fields.nix { sp = spField; };
  # Only real shared defaults belong in the project form. Per-app activation
  # and Nix package overrides are not mutations of modules.oxlint.settings.
  defaults = removeAttrs fields [
    "enable"
    "fix"
    "turboTask"
  ];
  apps = lib.filterAttrs (_: app: app.linting.oxlint.enable) sp.apps;
  packages = lib.unique (lib.mapAttrsToList (_: app: app.linting.oxlint.package) apps);
  appDir = name: app: if (app.path or "") == "" then "apps/${name}" else app.path;
  configFile =
    ox: if ox.configPath == null || ox.configPath == "" then ".oxlintrc.json" else ox.configPath;
  lintArgs =
    ox: fix:
    [
      "-c"
      (configFile ox)
    ]
    ++ lib.optional fix "--fix"
    ++ [ "--" ]
    ++ ox.paths;
in
mkModule {
  name = "oxlint";
  meta = {
    name = "OxLint";
    description = "Lint JavaScript and TypeScript apps with OxLint";
    category = "development";
    icon = "search-code";
    version = "0.1.0";
    author = "Stackpanel";
    homepage = "https://oxc.rs";
  };
  source = {
    type = "flake-input";
    flakeInput = "oxlint";
  };
  readme = ../README.md;
  priority = 50;
  tags = [
    "linting"
    "javascript"
    "typescript"
    "react"
    "oxc"
  ];
  features = {
    files = true;
    scripts = true;
    packages = true;
    healthchecks = true;
  };
  healthcheckModule = "oxlint";
  defaultEnable = apps != { };
  settings = defaults;
  packages = lib.optionals sp.enable packages;
  appOptions.linting.oxlint = fields;
  appModule =
    { name, config, ... }:
    let
      ox = config.linting.oxlint;
    in
    {
      options.linting.oxlint.package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.oxlint;
        defaultText = lib.literalExpression "pkgs.oxlint";
        description = "OxLint package for this app's scripts and pre-commit wrapper.";
      };
      config.linting.oxlint = lib.mapAttrs (n: _: lib.mkDefault sp.modules.oxlint.settings.${n}) defaults;
      # The host wraps each app's tooling.linters and registers those wrappers
      # with pre-commit. Don't also append to git-hooks.extraLinters.
      config.tooling.linters =
        lib.mkIf (!isGlobalEval && sp.enable && sp.modules.oxlint.enable && ox.enable && ox.gitHook)
          [
            {
              package = ox.package;
              bin = "oxlint";
              cwd = appDir name config;
              args = lintArgs ox false;
            }
          ];
    };

  config =
    _:
    lib.mkIf sp.enable (
      lib.mkMerge [
        {
          stackpanel.panels.oxlint-app-config =
            (panels.mkPanelFromSpFields {
              module = "oxlint";
              title = "OxLint Configuration";
              icon = "search-code";
              inherit fields;
              optionPrefix = "linting.oxlint";
              apps = sp.apps;
              exclude = [ "turboTask" ];
              order = 52;
            })
            // {
              slot = "app:tab";
            };
        }
        (lib.mkIf (apps != { } && !isGlobalEval) (
          import ./outputs.nix {
            inherit
              apps
              appDir
              configFile
              lintArgs
              lib
              pkgs
              packages
              ;
          }
        ))
      ]
    );
} args
