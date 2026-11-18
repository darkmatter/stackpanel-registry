# Remix

Adds `framework.remix` to Stackpanel apps. It contributes the app's dev and build tasks, deployment metadata, and a per-app configuration panel in Studio. It does not install or update JavaScript dependencies: pin `@remix-run/dev` in the app's manifest and install it with the workspace's package manager first.

Add the module to the consumer flake:

```nix
inputs.remix.url = "github:darkmatter/stackpanel-registry?dir=modules/remix";
```

Then select the framework in `.stack/config.nix`:

```nix
apps.web.framework.remix.enable = true;
```

The default commands are `remix vite:dev` and `remix vite:build`, run from the app directory with package binaries on `PATH`. Existing projects can override these with their own app tasks. Configure the deployment host separately; enabling the framework alone does not deploy anything.
