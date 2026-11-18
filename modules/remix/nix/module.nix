{ lib, config, ... }@args:
let
  inherit (lib.stackpanel) mkModule panels spField;
  fields = {
    enable = spField.bool {
      index = 1;
      description = "Use Remix for this app.";
      default = false;
      ui.label = "Use Remix";
    };
  };
in
mkModule {
  name = "remix";
  meta = {
    name = "Remix";
    description = "Remix framework configuration and tasks for Vite-based Remix apps";
    icon = "disc-3";
    category = "framework";
    version = "0.1.0";
  };
  source = {
    type = "flake-input";
    flakeInput = "remix";
  };
  defaultEnable = true;
  readme = builtins.readFile ../README.md;
  appOptions.framework.remix = fields;
  config = _: {
    stackpanel.appFrameworks.remix = {
      label = "Remix";
      icon = "disc-3";
      compatibleRuntimes = [
        "bun"
        "node"
      ];
      defaultTasks = {
        dev = "remix vite:dev";
        build = "remix vite:build";
      };
      deployMetadata = _: { cloudflareAdapter = "remix"; };
    };
    stackpanel.panels.remix-framework =
      (panels.mkPanelFromSpFields {
        module = "remix";
        title = "Remix";
        icon = "disc-3";
        inherit fields;
        exclude = [ ];
        optionPrefix = "framework.remix";
        apps = lib.filterAttrs (_: app: app.framework.remix.enable) config.stackpanel.apps;
      })
      // {
        slot = "app:framework";
      };
  };
} args
