{ lib, config, ... }@args:
let
  inherit (lib.stackpanel) mkModule panels spField;
  fields = {
    enable = spField.bool {
      index = 1;
      description = "Use Next.js for this app.";
      default = false;
      ui.label = "Use Next.js";
    };
    output = spField.string {
      index = 2;
      description = "Next.js output mode passed to the deployment provider.";
      default = "standalone";
      ui = {
        label = "Output mode";
        type = "FIELD_TYPE_SELECT";
        options = [
          "standalone"
          "export"
        ];
      };
    };
  };
in
mkModule {
  name = "nextjs";
  meta = {
    name = "Next.js";
    description = "Next.js framework configuration and tasks for App Router and Pages Router";
    icon = "panels-top-left";
    category = "framework";
    version = "0.1.0";
  };
  source = {
    type = "flake-input";
    flakeInput = "nextjs";
  };
  defaultEnable = true;
  readme = builtins.readFile ../README.md;
  appOptions.framework.nextjs = fields // {
    output = (spField.asOption fields.output) // {
      type = lib.types.enum fields.output.ui.options;
    };
  };
  config = _: {
    stackpanel.appFrameworks.nextjs = {
      label = "Next.js";
      icon = "panels-top-left";
      compatibleRuntimes = [
        "bun"
        "node"
      ];
      defaultTasks = {
        dev = "next dev";
        build = "next build";
      };
      deployMetadata = app: {
        cloudflareAdapter = "nextjs";
        inherit (app.framework.nextjs) output;
      };
    };
    stackpanel.panels.nextjs-framework =
      (panels.mkPanelFromSpFields {
        module = "nextjs";
        title = "Next.js";
        icon = "panels-top-left";
        inherit fields;
        exclude = [ ];
        optionPrefix = "framework.nextjs";
        apps = lib.filterAttrs (_: app: app.framework.nextjs.enable) config.stackpanel.apps;
      })
      // {
        slot = "app:framework";
      };
  };
} args
