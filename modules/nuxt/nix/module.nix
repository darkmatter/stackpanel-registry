{ lib, config, ... }@args:
let
  inherit (lib.stackpanel) mkModule panels spField;
  fields = {
    enable = spField.bool {
      index = 1;
      description = "Use Nuxt for this app.";
      default = false;
      ui.label = "Use Nuxt";
    };
  };
in
mkModule {
  name = "nuxt";
  meta = {
    name = "Nuxt";
    description = "Nuxt framework configuration and tasks for Vue and Nitro apps";
    icon = "mountain";
    category = "framework";
    version = "0.1.0";
  };
  source = {
    type = "flake-input";
    flakeInput = "nuxt";
  };
  defaultEnable = true;
  readme = builtins.readFile ../README.md;
  appOptions.framework.nuxt = fields;
  config = _: {
    stackpanel.appFrameworks.nuxt = {
      label = "Nuxt";
      icon = "mountain";
      compatibleRuntimes = [
        "bun"
        "node"
      ];
      defaultTasks = {
        dev = "nuxt dev";
        build = "nuxt build";
      };
      deployMetadata = _: { cloudflareAdapter = "nuxt"; };
    };
    stackpanel.panels.nuxt-framework =
      (panels.mkPanelFromSpFields {
        module = "nuxt";
        title = "Nuxt";
        icon = "mountain";
        inherit fields;
        exclude = [ ];
        optionPrefix = "framework.nuxt";
        apps = lib.filterAttrs (_: app: app.framework.nuxt.enable) config.stackpanel.apps;
      })
      // {
        slot = "app:framework";
      };
  };
} args
