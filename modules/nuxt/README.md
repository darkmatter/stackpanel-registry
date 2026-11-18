# Nuxt

Adds `framework.nuxt` to Stackpanel apps. It contributes the app's dev and build tasks, deployment metadata, and a per-app configuration panel in Studio. It does not install or update JavaScript dependencies: pin `nuxt` in the app's manifest and install it with the workspace's package manager first.

Add the module to the consumer flake:

```nix
inputs.nuxt.url = "github:darkmatter/stackpanel-registry?dir=modules/nuxt";
```

Then select the framework in `.stack/config.nix`:

```nix
apps.web.framework.nuxt.enable = true;
```

The default commands are `nuxt dev` and `nuxt build`, run from the app directory with package binaries on `PATH`. Existing projects can override these with their own app tasks. Configure the deployment host separately; enabling the framework alone does not deploy anything.
