# Fly.io deployments

This registry module registers `fly` as a Stackpanel deployment host and backend. It generates a `fly.toml` for each selected app, configures the project's container builder, and deploys a pre-pushed image to Fly Machines. It does not call Fly or require credentials during evaluation.

## Configure a project

Migrating from the bundled `deployment-fly` integration? Enable the `fly` module after adding its flake input. Keep `deployment.fly.{organization,defaultRegion}` and per-app `deployment.fly.*` / `deployment.container.*` at their existing paths. The extension contributes infra scripts through managed package.json paths; SST is not required.

Install `fly` from the registry, or add the input to a Stackpanel project with input auto-import enabled:

```nix
inputs.fly.url = "github:darkmatter/stackpanel-registry?dir=modules/fly";
```

In Nix module form (omit the `stackpanel.` prefix in `.stack/config.nix`):

```nix
{
  stackpanel.modules.fly.enable = true;
  stackpanel.deployment.fly = {
    organization = "acme"; # optional Fly organization slug
    defaultRegion = "iad";
  };
  stackpanel.apps.api = {
    path = "apps/api";
    deployment = {
      enable = true;
      host = "fly";
      backend = "fly";
      container = { type = "bun"; port = 3000; };
      fly = {
        appName = "acme-api"; # globally unique; defaults to the app key
        region = "lhr";        # defaults to deployment.fly.defaultRegion
        memory = "512mb";
        cpuKind = "shared";
        cpus = 1;
        autoStop = "suspend";
        autoStart = true;
        minMachines = 0;
        forceHttps = true;
        env.LOG_LEVEL = "info";
      };
    };
  };
}
```

When `deployment.host` is null the provider uses `stackpanel.deployment.defaultHost`. Selecting the Fly host defaults `deployment.backend` to `fly`. Fly defaults the app's container name, builder type, port, registry, and optional startup command (`deployment.container.entrypoint`). The image tag comes from `apps.<key>.container.version` (`latest` by default). Keep the container image name aligned with the Fly app name. Put only **public** variables in `deployment.fly.env`: they appear in the generated configuration and image. Use Fly secrets for credentials.

## Build, push, deploy

Materialize the project files and enter the project's development shell. Authenticate `flyctl` with an account or deployment credentials appropriate to the organization and app. App creation requires permission to list/create apps. Building the Linux image requires a working container builder and the app's build output as an input to the pure Nix build. Build the app first if required by its container builder.

```sh
flyctl auth login
bun --cwd packages/infra run container:build:api
bun --cwd packages/infra run container:push:api
stack deploy api
fly-api status
```

`ship:api` in `packages/infra` runs image build, push, and deploy in order. `deploy:api`, `apps/api/.tasks/bin/deploy`, and `stack deploy api` deploy the published image without rebuilding it. The push workflow obtains registry credentials at runtime and removes its temporary authfile when it exits. Existing apps are reused; if the configured app isn't in the authenticated organization's app list, the workflow requests app creation. Fly does not accept NixOS machine targets.

## Studio and scripted actions

Open the app’s **Deployment** tab to edit machine sizing, scaling, app identity and region. The `deploy` action asks for confirmation before deploying. Under **Cloud → Fly.io**, select an app and check its live status. An empty project displays configuration guidance instead of issuing a Fly request.

Before using `status` or `deploy` as a module action, run `studio-fly-auth login` in the project shell. Unlike `stack deploy` or `fly-api`, agent actions do not inherit your home directory or `FLY_API_TOKEN`. This command establishes a separate Fly CLI session under the project’s gitignored `stackpanel.dirs.keys` directory. Use an account authorized for the selected apps; revoke the session with `studio-fly-auth logout`. `apps` does not require a login.

| Module action | JSON input on stdin | Output |
| --- | --- | --- |
| `apps` | `{}` | Evaluated org, region and app inventory as JSON; no credentials or environment values |
| `status` | `{"app":"api"}` | Live `flyctl status` output |
| `deploy` | `{"app":"api"}` | Deployment progress for the configured registry image |

`app` is the Stackpanel app key, not a free-form Fly app name. Only configured deployable apps appear in the action schema. `stack deploy` uses the backend executable's separate `APP ENV` argument contract.

The sidebar is an opaque sandboxed iframe. Its `actions:run` permission is restricted to the `apps` and `status` action IDs. The deployment action belongs to the app's host-rendered deployment panel and is not granted to the iframe. The sidebar cannot read or patch config or proxy service requests. `ui/panel.ts` imports the vanilla `@stackpanel/extension-sdk` helpers. The Nix bundle resolves that package from the consuming Stackpanel revision (`lib.stackpanel.extensionSdk`), with no npm download or second host flake pin.

## AWS workload identity (optional)

The flake exports `inputs.fly.lib.flyOidc`. Call it with the **target container's** `pkgs` to build an entrypoint for that architecture:

```nix
let
  flyOidc = inputs.fly.lib.flyOidc { inherit pkgs; };
  entrypoint = flyOidc.mkEntrypoint {
    sessionPrefix = "api";
    chamberService = "api/prod"; # or skipChamber = true;
  };
in {
  config.Entrypoint = [ "${entrypoint}/bin/fly-oidc-entrypoint" ];
  config.Cmd = [ "/app/bin/api" ];
}
```

Configure `deployment.fly.env` with `flyOidc.mkEnvConfig { roleArn = "arn:aws:iam::123456789012:role/api"; }`. Follow [Fly's OIDC guide](https://docs.fly.io/security/openid-connect) to restrict the AWS trust policy to the organization, app and intended audience. The helper reads the Machine identity file (or requests an identity from the documented Machine socket), obtains a short-lived AWS session, optionally loads the Chamber service, and executes the command. The session is acquired once at startup; for long-running applications that refresh credentials, use the AWS SDK's web-identity provider directly. No workload identity is sent to Studio.
