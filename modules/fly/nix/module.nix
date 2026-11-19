{
  lib,
  config,
  pkgs,
  isGlobalEval ? false,
  ...
}:
let
  cfg = config.stackpanel;
  inherit (cfg.deployment) fly;
  fields = import ./fields.nix { inherit lib; };
  enabledHost =
    app:
    (if app.deployment.host == null then cfg.deployment.defaultHost else app.deployment.host) == "fly";
  isFly =
    app:
    cfg.deployment.enable
    && app.deployment.enable
    && (enabledHost app || app.deployment.backend == "fly");
  apps = lib.filterAttrs (_: isFly) cfg.apps;
  workflows = import ./workflows.nix {
    inherit
      lib
      pkgs
      apps
      fly
      ;
    inherit (cfg.dirs) keys;
  };
  appActions = lib.optionals (!isGlobalEval && apps != { }) [
    "status"
    "deploy"
  ];
  sp = lib.stackpanel.spField;
  settings = {
    organization = sp.string {
      index = 1;
      optional = true;
      description = "Fly.io organization slug for application creation.";
      example = "acme";
    };
    defaultRegion = sp.string {
      index = 2;
      default = "iad";
      description = "Primary region for apps without a region override.";
    };
  };
in
{
  imports = [
    (lib.stackpanel.mkModule {
      name = "fly";
      meta = {
        name = "Fly.io Deployment";
        description = "Build container images and deploy apps to Fly Machines.";
        icon = "rocket";
        category = "deployment";
        version = "0.1.0";
        author = "Stackpanel";
        homepage = "https://fly.io/docs/";
      };
      source = {
        type = "registry";
        flakeInput = "fly";
        registryId = "fly";
      };
      readme = ../README.md;
      defaultEnable = apps != { };
      tags = [
        "fly"
        "cloud"
        "container"
      ];
      priority = 25;
      configPath = "deployment.fly";
      configSchema = lib.stackpanel.jsonSchemaFromSpFields settings;
      healthcheckModule = "fly";
      appModule = import ./app.nix {
        inherit
          lib
          cfg
          fields
          enabledHost
          isFly
          ;
      };
      features = {
        files = true;
        scripts = true;
        packages = true;
        tasks = true;
        healthchecks = true;
      };
      packages = lib.optionals (!isGlobalEval) [ pkgs.flyctl ];
      actions = module: lib.optionalAttrs (module.enable && !isGlobalEval) workflows.actions;
      panels = {
        fly-app-config =
          (lib.stackpanel.panels.mkPanelFromSpFields {
            module = "fly";
            title = "Fly.io configuration";
            icon = "rocket";
            inherit fields apps;
            optionPrefix = "deployment.fly";
            order = 25;
          })
          // {
            slot = "app:deployment";
            actions = appActions;
          };
      }
      // lib.optionalAttrs (!isGlobalEval) {
        fly-deployments = {
          module = "fly";
          title = "Fly.io deployments";
          icon = "rocket";
          type = "PANEL_TYPE_CUSTOM";
          slot = "sidebar";
          nav = {
            section = "Cloud";
            label = "Fly.io";
          };
          actions = [ "apps" ] ++ lib.optional (apps != { }) "status";
          uiBundle = {
            package = import ../ui/bundle.nix { inherit lib pkgs; };
            entry = "index.html";
            permissions = [ "actions:run" ];
            actionIds = [
              "apps"
              "status"
            ];
          };
        };
      };
      config = _: {
        stackpanel = lib.mkIf (!isGlobalEval && apps != { }) workflows.contributions;
      };
    })
  ];

  # Keep existing configuration paths valid even while the extension is disabled.
  options.stackpanel.deployment.fly = lib.mapAttrs (_: sp.asOption) settings;
  # Host/backend IDs are also the allowed values for per-app selections. Keep
  # those IDs valid when disabled, but only publish executable behavior when on.
  config.stackpanel.deploymentHosts.fly = {
    label = "Fly.io";
    icon = "rocket";
  };
  config.stackpanel.deployBackends.fly = {
    label = "Fly Machines";
    icon = "rocket";
    script = lib.mkIf (
      !isGlobalEval && cfg.modules.fly.enable && cfg.deployment.enable
    ) workflows.backend;
  };
}
