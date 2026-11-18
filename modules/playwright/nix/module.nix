{
  lib,
  pkgs,
  config,
  ...
}@args:
lib.stackpanel.mkModule {
  name = "playwright";
  meta = {
    name = "Playwright";
    description = "Adopt Playwright end-to-end tests in a Bun workspace";
    category = "testing";
    icon = "flask-conical";
    author = "Stackpanel";
    version = "0.1.0";
    homepage = "https://playwright.dev";
  };
  source = {
    type = "flake-input";
    flakeInput = "playwright";
  };
  readme = ../README.md;
  tags = [
    "playwright"
    "e2e"
    "testing"
    "browser"
  ];
  priority = 80;
  # test:e2e belongs to the selected Bun package.json, not stackpanel.scripts.
  features = {
    files = true;
    healthchecks = true;
    packages = true;
  };
  packages = [ (config.stackpanel.languages.javascript.bun.package or pkgs.bun) ];
  healthcheckModule = "playwright";
  settings = {
    version = {
      type = lib.types.str;
      default = "1.48.0";
      description = "@playwright/test version specification written to devDependencies. Match your existing lockfile on adoption.";
    };
    packageJson = {
      type = lib.types.str;
      default = "package.json";
      example = "apps/web/package.json";
      description = "Repo-relative package.json for the test:e2e script and dependency. Tests run in that package directory.";
    };
    generateConfig = {
      type = lib.types.bool;
      default = true;
      description = "Manage playwright.config.ts next to package.json. Disable before adoption to keep an existing test harness.";
    };
  };
  adoption = {
    revision = 1;
    question = {
      type = "bool";
      label = "Add Playwright end-to-end testing?";
      description = "Manages a Chromium config and CI workflow, adds test:e2e, and declares @playwright/test in the selected package manifest.";
      default = false;
      order = 30;
    };
    config.modules.playwright.enable = true;
  };
  config =
    cfg:
    let
      packageJson = lib.removePrefix "./" cfg.settings.packageJson;
      segments = lib.splitString "/" packageJson;
      validManifest =
        lib.last segments == "package.json"
        && lib.all (
          s:
          !(builtins.elem s [
            ""
            "."
            ".."
          ])
        ) segments;
      dir = if packageJson == "package.json" then "." else builtins.dirOf packageJson;
      configPath =
        if packageJson == "package.json" then "playwright.config.ts" else "${dir}/playwright.config.ts";
    in
    {
      stackpanel.files.entries =
        assert lib.assertMsg validManifest
          "modules.playwright.settings.packageJson must be a repo-relative package.json path";
        {
          ".github/workflows/e2e.yml" = {
            module = "playwright";
            source = "playwright";
            format = "yaml";
            writer = "full";
            adopt = "backup";
            description = "GitHub Actions workflow running the Playwright suite";
            value = {
              name = "e2e";
              on = {
                push.branches = [ "main" ];
                pull_request = { };
              };
              jobs.e2e = {
                runs-on = "ubuntu-latest";
                steps = [
                  { uses = "actions/checkout@v4"; }
                  {
                    uses = "DeterminateSystems/nix-installer-action@main";
                    "with".extra-conf = "accept-flake-config = true";
                  }
                  {
                    name = "Install workspace dependencies";
                    run = "nix develop --command bun install --frozen-lockfile";
                  }
                  {
                    name = "Install Chromium";
                    working-directory = dir;
                    run = ''nix develop "$GITHUB_WORKSPACE" --command bun run playwright install --with-deps chromium'';
                  }
                  {
                    name = "Test";
                    working-directory = dir;
                    run = ''nix develop "$GITHUB_WORKSPACE" --command bun run test:e2e'';
                  }
                ];
              };
            };
          };
          ".gitignore" = {
            modules = [ "playwright" ];
            format = "lines";
            writer = "block";
            dedupe = true;
            sort = true;
            lines = [
              "test-results/"
              "playwright-report/"
            ];
          };
          ${packageJson} = {
            modules = [ "playwright" ];
            format = "json";
            writer = "paths";
            adopt = "backup";
            ops = [
              {
                op = "set";
                path = "/scripts/test:e2e";
                value = "playwright test";
              }
              {
                op = "set";
                path = [
                  "devDependencies"
                  "@playwright/test"
                ];
                value = cfg.settings.version;
              }
            ];
          };
        }
        // lib.optionalAttrs cfg.settings.generateConfig {
          ${configPath} = {
            module = "playwright";
            source = "playwright";
            description = "Playwright Chromium test runner configuration";
            format = "text";
            writer = "full";
            adopt = "backup";
            path = ./playwright.config.ts;
          };
        };
      stackpanel.doctor.playwright = {
        displayName = "Playwright";
        browsers = {
          scope = "runtime";
          severity = "warning";
          description = "Chromium is available to this workspace's Playwright installation";
          script = ''
            cd -- "''${STACKPANEL_ROOT:-$PWD}"/${lib.escapeShellArg dir} || exit 1
            bun -e 'const {chromium} = require("@playwright/test"); const fs = require("node:fs"); fs.accessSync(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH || chromium.executablePath(), fs.constants.X_OK);'
          '';
          fixCommand = "bun install && (cd ${lib.escapeShellArg dir} && bun run playwright install chromium)";
          timeout = 5;
        };
      };
    };
} args
