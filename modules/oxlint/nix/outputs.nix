{
  apps,
  appDir,
  configFile,
  lintArgs,
  lib,
  pkgs,
  packages,
}:
let
  appNames = builtins.attrNames apps;
  generated = lib.filterAttrs (
    _: app:
    builtins.elem app.linting.oxlint.configPath [
      null
      ""
    ]
  ) apps;
  configJSON =
    app:
    builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/oxc-project/oxc/main/npm/oxlint/configuration_schema.json";
      inherit (app.linting.oxlint)
        categories
        plugins
        rules
        ignorePatterns
        ;
    };
  lintInApp =
    name: fix:
    let
      app = apps.${name};
      ox = app.linting.oxlint;
    in
    ''
      cd -- "''${STACKPANEL_ROOT:-$PWD}"/${lib.escapeShellArg (appDir name app)} || exit 1
      exec ${lib.getExe' ox.package "oxlint"} ${lib.escapeShellArgs (lintArgs ox fix)}
    '';
  lintAll = fix: ''
    result=0
    ${lib.concatMapStringsSep "\n" (name: ''
      printf 'Linting %s\n' ${lib.escapeShellArg name}
      (
        ${lintInApp name fix}
      ) || result=$?
    '') appNames}
    exit "$result"
  '';
in
{
  stackpanel.files.entries = lib.mapAttrs' (
    name: app:
    lib.nameValuePair "${appDir name app}/.oxlintrc.json" {
      module = "oxlint";
      source = "oxlint";
      format = "text";
      text = configJSON app;
      description = "OxLint configuration for ${name}";
    }
  ) generated;
  stackpanel.scripts = lib.mkMerge [
    (lib.concatMapAttrs (name: _: {
      "lint-${name}" = {
        module = "oxlint";
        description = "Lint ${name} with OxLint";
        exec = lintInApp name false;
      };
      "lint-${name}-fix" = {
        module = "oxlint";
        description = "Lint and fix ${name} with OxLint";
        exec = lintInApp name true;
      };
    }) apps)
    {
      lint = {
        module = "oxlint";
        description = "Lint all OxLint apps";
        exec = lintAll false;
      };
      lint-fix = {
        module = "oxlint";
        description = "Lint and fix all OxLint apps";
        exec = lintAll true;
      };
    }
  ];
  stackpanel.panels.oxlint-status = {
    module = "oxlint";
    title = "OxLint Status";
    type = "PANEL_TYPE_STATUS";
    order = 50;
    fields = [
      {
        name = "apps";
        type = "FIELD_TYPE_JSON";
        value = builtins.toJSON (
          lib.mapAttrsToList (name: app: {
            inherit name;
            path = appDir name app;
            inherit (app.linting.oxlint) plugins gitHook turboTask;
          }) apps
        );
      }
      {
        name = "commands";
        type = "FIELD_TYPE_JSON";
        value = builtins.toJSON [
          {
            name = "lint";
            description = "Run OxLint on all apps";
          }
          {
            name = "lint-fix";
            description = "Run OxLint --fix on all apps";
          }
        ];
      }
    ];
  };
  stackpanel.doctor.oxlint = {
    displayName = "OxLint";
    eval = {
      scope = "build";
      description = "Enabled OxLint apps resolve their lint arguments";
      required = true;
      derivation = pkgs.writeText "oxlint-app-arguments.json" (
        builtins.toJSON (lib.mapAttrs (_: app: lintArgs app.linting.oxlint false) apps)
      );
    };
    packages = {
      scope = "build";
      description = "Each configured OxLint binary runs";
      required = true;
      derivation = pkgs.runCommand "oxlint-packages-check" { } (
        lib.concatMapStringsSep "\n" (pkg: ''
          ${lib.getExe' pkg "oxlint"} --version >> "$out"
        '') packages
      );
    };
    config = {
      scope = "build";
      description = "Generated .oxlintrc.json files have the expected structure";
      derivation = pkgs.runCommand "oxlint-config-check" { } (
        ''mkdir -p "$out"''
        + "\n"
        + lib.concatMapStringsSep "\n" (app: ''
          ${lib.getExe pkgs.jq} -e 'has("categories") and has("rules") and has("plugins") and has("ignorePatterns")' ${pkgs.writeText "oxlintrc.json" (configJSON app)}
        '') (builtins.attrValues generated)
      );
    };
    oxlint-installed = {
      description = "OxLint is on the devshell PATH";
      script = "oxlint --version";
      severity = "critical";
      timeout = 5;
    };
    oxlint-config = {
      description = "Each enabled app has its configured OxLint file";
      script = ''
        result=0
        ${lib.concatMapStringsSep "\n" (
          name:
          let
            app = apps.${name};
            file = "${appDir name app}/${configFile app.linting.oxlint}";
          in
          ''
            if ! test -f "''${STACKPANEL_ROOT:-$PWD}"/${lib.escapeShellArg file}; then
              printf 'Missing %s\n' ${lib.escapeShellArg file}
              result=1
            fi
          ''
        ) appNames}
        exit "$result"
      '';
      severity = "warning";
      timeout = 5;
    };
    oxlint-passes = {
      description = "OxLint passes for all enabled apps";
      script = lintAll false;
      severity = "warning";
      timeout = 60;
    };
  };
}
