{
  lib,
  pkgs,
  apps,
  fly,
  keys,
}:
let
  q = lib.escapeShellArg;
  flyctl = lib.getExe' pkgs.flyctl "flyctl";
  jq = lib.getExe pkgs.jq;
  names = builtins.attrNames apps;
  orgArgs = lib.escapeShellArgs (
    lib.optionals (fly.organization != null) [
      "--org"
      fly.organization
    ]
  );
  appPath =
    name: app:
    let
      configured = app.path or "";
      path = if configured == null || configured == "" then "apps/${name}" else configured;
    in
    if lib.hasPrefix "/" path || builtins.elem ".." (lib.splitString "/" path) then
      throw "fly: apps.${name}.path must be relative to the project root"
    else
      path;

  # Module actions and stack deploy always start in the active project root.
  # Interactive commands and .tasks/bin scripts also work from an app directory.
  cdRoot = ''
    if [[ -n "''${STACKPANEL_ROOT:-}" ]]; then
      cd "$STACKPANEL_ROOT"
    elif [[ ! -f flake.nix ]]; then
      cd "$(git rev-parse --show-toplevel)"
    fi
  '';
  # Action processes have no ambient credentials or HOME. Use only a session
  # the operator explicitly established in this project's ignored keys dir.
  sessionDir = "${keys}/fly-studio";
  studioSession = ''
    root=$(pwd -P)
    home="$root"/${q sessionDir}
    if [[ "$(${pkgs.coreutils}/bin/realpath -m -- "$home/.fly/config.yml")" != "$home/.fly/config.yml" ]]; then
      echo 'Refusing an indirect Fly credential path' >&2; exit 2
    fi
    export HOME="$home" FLY_CONFIG_DIR="$home/.fly" XDG_CONFIG_HOME="$home/.config"
  '';
  perApp = lib.mapAttrs (
    name: app:
    let
      f = app.deployment.fly;
      path = appPath name app;
      toml = "${path}/fly.toml";
      image = "registry.fly.io/${f.appName}:${app.container.version}";
      # Never interpret a transient API/auth error as an app not existing.
      # Org-scoped listing also prevents an identically named app in another
      # org from becoming a deployment target.
      ensureApp = ''
        exists=$(${flyctl} apps list --json ${orgArgs} | ${jq} -er --arg target ${q f.appName} '
          if type != "array" or any(.[]; (.Name // .name | type) != "string") then error("invalid Fly app list")
          elif any(.[]; (.Name // .name) == $target) then "present" else "absent" end')
        if [[ "$exists" == absent ]]; then
          ${flyctl} apps create --name ${q f.appName} ${orgArgs} --yes
        fi
      '';
      deploy = pkgs.writeShellScript "fly-deploy" ''
        set -euo pipefail
        [[ -f ${q toml} ]] || { echo ${q "Missing ${toml}; materialize the project files before deploying."} >&2; exit 1; }
        ${ensureApp}
        exec ${flyctl} deploy --app ${q f.appName} --config ${q toml} --image ${q image} --yes
      '';
      build = pkgs.writeShellScript "fly-container-build" ''
        set -euo pipefail
        exec nix build ${q ".#packages.x86_64-linux.container-${name}"}
      '';
      push = pkgs.writeShellScript "fly-container-push" ''
        set -euo pipefail
        if [[ ${
          q (if app.container.name == null then name else app.container.name)
        } != ${q f.appName} ]]; then
          echo 'Set container.name to the Fly app name before pushing to its registry.' >&2; exit 2
        fi
        ${ensureApp}
        # skopeo reads the short-lived Fly credential on stdin. It never
        # appears in a derivation, process argument or action output.
        tmp=$(mktemp -d)
        trap 'rm -rf -- "$tmp"' EXIT
        ${flyctl} auth token | ${pkgs.skopeo}/bin/skopeo login --username x --password-stdin \
          --authfile "$tmp/auth.json" registry.fly.io
        nix run ${q ".#copy-container-${name}"} -- docker://registry.fly.io/ --dest-authfile "$tmp/auth.json"
      '';
      ship = pkgs.writeShellScript "fly-ship" ''
        set -euo pipefail
        ${build}
        ${push}
        exec ${deploy}
      '';
      scriptFiles = {
        "fly-build" = build;
        "fly-push" = push;
        "fly-ship" = ship;
        inherit deploy;
      };
      taskPath = script: "${path}/.tasks/bin/${script}";
    in
    {
      inherit deploy;
      status = "${flyctl} status --app ${q f.appName}";
      defaultEnv = app.deployment.defaultEnv;
      files = {
        ${toml} = {
          module = "fly";
          source = "fly";
          description = "Fly Machines configuration for ${name}";
          format = "toml";
          value = {
            app = f.appName;
            primary_region = f.region;
            env = {
              PORT = toString app.container.port;
            }
            // f.env;
            http_service = {
              internal_port = app.container.port;
              force_https = f.forceHttps;
              auto_stop_machines = f.autoStop;
              auto_start_machines = f.autoStart;
              min_machines_running = f.minMachines;
              processes = [ "app" ];
            };
            vm = [
              {
                inherit (f) memory cpus;
                cpu_kind = f.cpuKind;
              }
            ];
          };
        };
      }
      // lib.mapAttrs' (
        script: exe:
        lib.nameValuePair (taskPath script) {
          module = "fly";
          source = "fly";
          description = "${script} for ${name} on Fly.io";
          format = "symlink";
          target = toString (
            pkgs.writeShellScript script ''
              set -euo pipefail
              ${cdRoot}
              exec ${exe}
            ''
          );
        }
      ) scriptFiles;
      # Keep committed package.json entries independent of Nix store hashes.
      packageOps =
        lib.mapAttrsToList
          (alias: script: {
            op = "set";
            path = [
              "scripts"
              "${alias}:${name}"
            ];
            value = "cd ../.. && ${q "./${taskPath script}"}";
          })
          {
            "container:build" = "fly-build";
            "container:push" = "fly-push";
            deploy = "deploy";
            ship = "fly-ship";
          };
      wrapper = {
        module = "fly";
        description = "flyctl for ${name} (app ${f.appName})";
        args = [
          {
            name = "command";
            description = "flyctl subcommand";
            required = true;
          }
          {
            name = "...";
            description = "Additional flyctl arguments";
          }
        ];
        exec = ''
          ${cdRoot}
          if [[ $# -eq 0 ]]; then exec ${flyctl} --help; fi
          exec ${flyctl} "$@" --app ${q f.appName} --config ${q toml}
        '';
      };
    }
  ) apps;

  dispatch = command: ''
    case "$app" in
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: scripts: "${q name}) ${command scripts} ;;") perApp
      )}
      *) echo 'Unknown or disabled Fly application' >&2; exit 2 ;;
    esac
  '';
  appAction = name: label: command: {
    inherit label;
    argsSchema = {
      type = "object";
      properties.app = {
        type = "string";
        enum = names;
        description = "Stackpanel application key";
      };
      required = [ "app" ];
      additionalProperties = false;
    };
    outputMode = "stream";
    script = toString (
      pkgs.writeShellScript "fly-action-${name}" ''
        set -euo pipefail
        app=$(${jq} -ers --argjson allowed ${q (builtins.toJSON names)} '
          if length == 1 and (.[0] | type == "object" and keys == ["app"] and (.app | type == "string")) then .[0].app else null end |
          . as $id | if ($allowed | index($id)) != null then $id else error("expected a configured app key") end')
        ${studioSession}
        if [[ ! -s "$FLY_CONFIG_DIR/config.yml" ]]; then
          echo 'Run studio-fly-auth login in the project shell before using authenticated Fly actions.' >&2; exit 1
        fi
        ${dispatch command}
      ''
    );
  };
  inventory = pkgs.writeText "fly-inventory.json" (
    builtins.toJSON {
      inherit (fly) organization defaultRegion;
      apps = lib.mapAttrsToList (name: app: {
        app = name;
        inherit (app.deployment.fly) appName region memory;
      }) apps;
    }
  );
in
{
  backend = toString (
    pkgs.writeShellScript "fly-deploy-backend" ''
      set -euo pipefail
      if [[ $# != 2 ]]; then echo 'Fly expects an app and environment, without machine targets' >&2; exit 2; fi
      app=$1
      ${dispatch (s: ''
        if [[ "$2" != ${q s.defaultEnv} ]]; then echo 'Environment does not match the configured Fly deployment' >&2; exit 2; fi
        exec ${s.deploy}
      '')}
    ''
  );
  actions = {
    apps = {
      label = "List configured Fly applications";
      argsSchema = {
        type = "object";
        properties = { };
        additionalProperties = false;
      };
      outputMode = "json";
      script = toString (
        pkgs.writeShellScript "fly-action-apps" ''
          set -euo pipefail
          ${jq} -es 'length == 1 and .[0] == {}' >/dev/null
          exec ${pkgs.coreutils}/bin/cat ${inventory}
        ''
      );
    };
  }
  // lib.optionalAttrs (apps != { }) {
    status = appAction "status" "Check Fly status" (s: "exec ${s.status}");
    deploy = (appAction "deploy" "Deploy published image" (s: "exec ${s.deploy}")) // {
      confirm = "Deploy the configured image to the selected Fly application? This may create Fly resources and incur charges.";
    };
  };
  contributions = {
    docker.enable = lib.mkDefault true;
    files.entries = lib.mkMerge (
      (map (s: s.files) (lib.attrValues perApp))
      ++ [
        {
          "packages/infra/package.json" = {
            modules = [ "fly" ];
            format = "json";
            writer = "paths";
            adopt = "backup";
            ops = lib.concatMap (s: s.packageOps) (lib.attrValues perApp);
          };
          "packages/infra/turbo.json" = {
            modules = [ "fly" ];
            format = "json";
            writer = "paths";
            adopt = "backup";
            ops = [
              {
                op = "appendUnique";
                path = [ "extends" ];
                value = "//";
              }
            ];
          };
        }
      ]
    );
    scripts = (lib.mapAttrs' (name: s: lib.nameValuePair "fly-${name}" s.wrapper) perApp) // {
      studio-fly-auth = {
        module = "fly";
        description = "Log in or out of the project-local Fly session used by Studio actions";
        exec = ''
          set -euo pipefail
          if [[ $# != 1 || ( "$1" != login && "$1" != logout ) ]]; then
            echo 'Usage: studio-fly-auth login|logout' >&2; exit 2
          fi
          ${cdRoot}
          if ! git check-ignore -q -- ${q "${sessionDir}/.fly/config.yml"}; then
            echo 'Refusing to store Fly credentials: the project keys directory must be gitignored.' >&2; exit 1
          fi
          ${studioSession}
          umask 077
          mkdir -p -- "$HOME/.fly"
          chmod 700 -- "$HOME" "$HOME/.fly"
          unset FLY_ACCESS_TOKEN FLY_API_TOKEN
          exec ${flyctl} auth "$1"
        '';
      };
    };
    tasks =
      lib.mapAttrs
        (name: dependencies: {
          module = "fly";
          description = "Fly deployment: ${name}";
          cache = false;
          dependsOn = dependencies;
        })
        {
          "build:container" = [ ];
          "container:build" = [ "build:container" ];
          "container:push" = [ "container:build" ];
          deploy = [ "container:push" ];
        };
    doctor.fly = {
      enable = true;
      displayName = "Fly.io";
      flyctl-installed = {
        description = "Fly CLI version";
        script = "${flyctl} version";
        severity = "critical";
        timeout = 5;
      };
      flyctl-auth = {
        description = "Authenticated Fly account";
        script = "${flyctl} auth whoami";
        severity = "warning";
        timeout = 10;
      };
    };
  };
}
