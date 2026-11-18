# These fields drive the Nix options, runtime settings schema, and Studio editor.
{ sp }:
{
  enable = sp.bool {
    index = 1;
    default = false;
    description = "Generate lint scripts and configuration for this app.";
    ui.label = "Enable OxLint";
  };
  configPath = sp.string {
    index = 2;
    optional = true;
    example = "oxlint.json";
    description = "Existing config relative to the app directory. Leave unset to generate .oxlintrc.json.";
    ui.label = "Config path";
  };
  plugins = sp.string {
    index = 3;
    repeated = true;
    default = [ ];
    description = "OxLint plugins to enable in the generated config.";
    example = [
      "react"
      "typescript"
    ];
    ui.label = "Plugins";
  };
  categories = sp.string {
    index = 4;
    mapKey = "string";
    default = {
      correctness = "error";
      suspicious = "warn";
      pedantic = "off";
      style = "off";
      nursery = "off";
    };
    description = "Category severities in the generated config (off, warn, or error).";
    ui.label = "Categories";
  };
  rules = sp.string {
    index = 5;
    mapKey = "string";
    default = { };
    example = {
      no-console = "warn";
    };
    description = "Rule overrides in the generated config (off, warn, or error).";
    ui.label = "Rules";
  };
  ignorePatterns = sp.string {
    index = 6;
    repeated = true;
    default = [
      "node_modules"
      "dist"
      "build"
      ".next"
      "coverage"
      "*.min.js"
      "*.bundle.js"
    ];
    description = "Patterns to ignore, relative to the app directory.";
    ui.label = "Ignore patterns";
  };
  paths = sp.string {
    index = 7;
    repeated = true;
    default = [
      "src"
      "."
    ];
    description = "Paths to lint, relative to the app directory.";
    ui.label = "Paths";
  };
  fix = sp.bool {
    index = 8;
    default = false;
    description = "Legacy preference. Checks never modify files; use the explicit -fix scripts to apply fixes.";
    ui = null;
  };
  gitHook = sp.bool {
    index = 9;
    default = true;
    description = "Run this app's read-only lint wrapper in the pre-commit hook.";
    ui.label = "Pre-commit hook";
  };
  turboTask = sp.bool {
    index = 10;
    default = false;
    description = "Deprecated compatibility setting; no Turbo task is generated.";
    ui = null;
  };
}
