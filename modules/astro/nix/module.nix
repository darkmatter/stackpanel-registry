{ lib, config, ... }@args:
let
  inherit (lib.stackpanel) mkModule panels spField;
  fields = {
    enable = spField.bool {
      index = 1;
      description = "Use Astro for this app.";
      default = false;
      ui.label = "Use Astro";
    };
  };
in
mkModule {
  name = "astro";
  meta = {
    name = "Astro";
    description = "Astro framework configuration and tasks for static and server-rendered sites";
    icon = "rocket";
    category = "framework";
    version = "0.1.0";
  };
  source = {
    type = "flake-input";
    flakeInput = "astro";
  };
  defaultEnable = true;
  readme = builtins.readFile ../README.md;
  appOptions.framework.astro = fields;
  config = _: {
    stackpanel.appFrameworks.astro = {
      label = "Astro";
      icon = "rocket";
      compatibleRuntimes = [
        "bun"
        "node"
      ];
      defaultTasks = {
        dev = "astro dev";
        build = "astro build";
      };
      deployMetadata = _: { cloudflareAdapter = "astro"; };
    };
    stackpanel.panels.astro-framework =
      (panels.mkPanelFromSpFields {
        module = "astro";
        title = "Astro";
        icon = "rocket";
        inherit fields;
        exclude = [ ];
        optionPrefix = "framework.astro";
        apps = lib.filterAttrs (_: app: app.framework.astro.enable) config.stackpanel.apps;
      })
      // {
        slot = "app:framework";
      };
  };
} args
