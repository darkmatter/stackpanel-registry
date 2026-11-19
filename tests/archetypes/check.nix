{
  lib,
  pkgs,
  legacyPackages,
}:
let
  sp = legacyPackages.stackpanelFullConfig;
  state = legacyPackages.stackpanelSerializable;
  frameworks = {
    docs = {
      id = "nextjs";
      bin = "next";
    };
    blog = {
      id = "astro";
      bin = "astro";
    };
    shop = {
      id = "remix";
      bin = "remix";
    };
    landing = {
      id = "nuxt";
      bin = "nuxt";
    };
  };
  rendered = sp.infra.modules.deployment.inputs.apps;
  sidebar = state.panels.fly-deployments;
  fly = sp.modules.fly.actions;
  files = sp.files.entries;
  hook = sp.git-hooks.hooks.pre-commit.stackpanel-linters-0;
  preview = legacyPackages.stackpanelSpeculate { config = sp.addons.playwright.config; };
  offered = path: builtins.any (f: f.path == path) preview.files;
  # Probe the generated task launcher, not a framework installation. A real
  # build would additionally need the app's JS dependencies and lockfile.
  runTasks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      app: fw:
      let
        path = sp.apps.${app}.path;
      in
      ''
        mkdir -p ${path}/node_modules/.bin
        ln -s "$probe" ${path}/node_modules/.bin/${fw.bin}
        ${lib.concatMapStringsSep "\n"
          (
            task:
            let
              subcommand = if fw.id == "remix" then "vite:${task}" else task;
              wrapper = files."${path}/.tasks/bin/${task}".target;
            in
            ''test "$(${wrapper})" = "$PWD/${path} ${fw.bin} ${subcommand}"''
          )
          [
            "dev"
            "build"
          ]
        }
      ''
    ) frameworks
  );
in
assert lib.all (
  app:
  let
    id = frameworks.${app}.id;
    panel = state.panels."${id}-framework";
  in
  rendered.${app}.cloudflareAdapter == id && panel.slot == "app:framework" && panel.apps ? ${app}
) (builtins.attrNames frameworks);
assert rendered.docs.output == "export";
assert
  state.panels.oxlint-app-config.slot == "app:tab"
  && state.panels.oxlint-app-config.apps.docs.config.gitHook == "true";
assert hook.entry == lib.getExe (builtins.head sp.appsComputed.docs.wrappedTooling.linters);
assert !sp.modules.playwright.enable && !(files ? "sites/nextjs/playwright.config.ts");
assert offered "sites/nextjs/playwright.config.ts" && offered ".github/workflows/e2e.yml";
assert builtins.elem "sites/nextjs/package.json" (
  map (f: f.path) preview.moduleOutputs.playwright.files
);
assert
  state.panels.fly-app-config.slot == "app:deployment"
  && builtins.elem "deploy" state.panels.fly-app-config.actions;
assert fly.deploy.confirm != null && fly.deploy.argsSchema.properties.app.enum == [ "api" ];
assert sidebar.slot == "sidebar" && sidebar.uiBundle.permissions == [ "actions:run" ];
assert
  sidebar.uiBundle.actionIds == [
    "apps"
    "status"
  ]; # never grant deploy to the iframe
assert files."services/api/fly.toml".value.primary_region == "ams";
pkgs.runCommand "registry-archetypes" { nativeBuildInputs = [ pkgs.jq ]; } ''
  export STACKPANEL_ROOT="$PWD"
  probe=${pkgs.writeShellScript "record-framework-invocation" ''printf '%s %s %s\n' "$PWD" "''${0##*/}" "$*"''}
  ${runTasks}
  mkdir -p sites/nextjs/src
  cp ${
    pkgs.writeText "oxlint-config.json" files."sites/nextjs/.oxlintrc.json".text
  } sites/nextjs/.oxlintrc.json
  echo 'export const valid = 1;' > sites/nextjs/src/app.js
  ${hook.entry}
  echo 'debugger;' > sites/nextjs/src/app.js
  if ${hook.entry} > lint.log 2>&1; then echo 'hook accepted a forbidden debugger statement' >&2; exit 1; fi
  grep -F 'no-debugger' lint.log
  bundle=${sidebar.uiBundle.package}
  test -s "$bundle/${sidebar.uiBundle.entry}"
  grep -F 'src="./panel.js"' "$bundle/${sidebar.uiBundle.entry}"
  test -s "$bundle/panel.js"
  test -s "$bundle/panel.css"
  ${pkgs.nodejs}/bin/node --check "$bundle/panel.js"
  # Inventory is read-only and local. Do not call flyctl or use credentials.
  echo '{}' | ${fly.apps.script} | jq -e '.apps == [{app:"api", appName:"archetype-smoke-api", region:"ams", memory:"512mb"}]'
  touch "$out"
''
