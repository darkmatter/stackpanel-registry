# Astro

Adds `framework.astro` to Stackpanel apps. It contributes the app's dev and build tasks, deployment metadata, and a per-app configuration panel in Studio. It does not install or update JavaScript dependencies: pin `astro` in the app's manifest and install it with the workspace's package manager first.

Add the module to the consumer flake:

```nix
inputs.astro.url = "github:darkmatter/stackpanel-registry?dir=modules/astro";
```

Then select the framework in `.stack/config.nix`:

```nix
apps.web.framework.astro.enable = true;
```

The default commands are `astro dev` and `astro build`, run from the app directory with package binaries on `PATH`. Existing projects can override these with their own app tasks. Configure the deployment host separately; enabling the framework alone does not deploy anything.
