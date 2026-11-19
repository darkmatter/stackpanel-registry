# Next.js

Adds `framework.nextjs` to Stackpanel apps. It contributes the app's dev and build tasks, deployment metadata, and a per-app configuration panel in Studio. It does not install or update JavaScript dependencies: pin `next` in the app's manifest and install it with the workspace's package manager first.

Add the module to the consumer flake:

```nix
inputs.nextjs.url = "github:darkmatter/stackpanel-registry?dir=modules/nextjs";
```

Then select the framework in `.stack/config.nix`:

```nix
apps.web.framework.nextjs.enable = true;
```

The default commands are `next dev` and `next build`, run from the app directory with package binaries on `PATH`. Existing projects can override these with their own app tasks. Configure the deployment host separately; enabling the framework alone does not deploy anything.

`apps.web.framework.nextjs.output` accepts `"standalone"` (default) or `"export"`. This reports the configured Next.js build mode to deployment providers; set `output` in `next.config` to match.
