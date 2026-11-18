# Playwright

Install the `playwright` registry module, or add the flake input:

```nix
inputs.playwright.url = "github:darkmatter/stackpanel-registry?dir=modules/playwright";
```

Installation makes the adoption offer available to `stack setup`; it does not enable tests or download browsers. Accept the offer or set `modules.playwright.enable = true` in `.stack/config.nix`. Enabling the module adds Bun to the project's devshell.

By default the module manages a root `playwright.config.ts` for `./e2e`, `.github/workflows/e2e.yml`, two lines in the shared `.gitignore` block, and just two paths in `package.json`: `scripts.test:e2e` (`playwright test`) and `devDependencies."@playwright/test"` (default `1.48.0`). On first adoption existing full files and manifests use the backup policy. Review the preview before enabling.

**Existing workspace suite:** set `packageJson` to its manifest, match its dependency specification, and set `generateConfig = false` **before adoption**. This preserves custom Playwright config, including web servers, custom browser paths, and authentication setup. For the Stackpanel web workspace:

```nix
# .stack/config.nix
modules.playwright = {
  enable = true;
  settings = {
    packageJson = "apps/web/package.json";
    version = "^1.59.1";
    generateConfig = false;
  };
};
```

After reconciliation run `bun install` from the repo root and commit any lockfile changes: CI uses `--frozen-lockfile`. In the selected package directory run `bun run playwright install chromium`, then `bun run test:e2e`. Point `PLAYWRIGHT_BASE_URL` at a running app when using the generated config. The workflow installs Chromium and runs the package's tests in the project devshell; the test suite is responsible for starting any services it needs.

`stack doctor` checks the workspace's Chromium executable but never installs it. Disabling the module drops its managed outputs on reconciliation; it does not uninstall user-level browser caches or remove other modules' manifest entries.
