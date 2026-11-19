# OxLint

Lint one or more JavaScript/TypeScript apps with the consumer's `pkgs.oxlint`. Install the `oxlint` registry module, or add this input to a Stackpanel flake:

```nix
inputs.oxlint.url = "github:darkmatter/stackpanel-registry?dir=modules/oxlint";
```

Existing `apps.<app>.linting.oxlint` configurations continue to work: if any app opts in, the project module is enabled by default. An explicit `modules.oxlint.enable = false` disables its outputs without deleting per-app settings. To start with an empty list, enable the project module and select apps in their **OxLint Configuration** Studio tabs.

```nix
# .stack/config.nix
{
  modules.oxlint.settings.ignorePatterns = [ "node_modules" "dist" "coverage" ];
  apps.web.linting.oxlint = {
    enable = true;
    paths = [ "src" ];
    plugins = [ "react" "typescript" ];
    rules.no-console = "warn";
  };
}
```

The project settings are defaults; an explicit app value takes precedence. Each opted-in app gets `.oxlintrc.json` unless `configPath` names an existing app-relative file (including an explicitly user-managed `.oxlintrc.json`). Set `package` in Nix to select a different derivation for an app; it must provide `bin/oxlint`.

- `lint` and `lint-<app>` check without modifying files; `lint-fix` and `lint-<app>-fix` apply fixes. The legacy `fix` and `turboTask` keys remain accepted; neither turns a check into a write.
- Each opted-in app contributes one `tooling.linters` step for pre-commit. Set `gitHook = false` on the app to omit just that step without losing scripts.
- `stack doctor` checks the executable, config files, and lint results. Build-scope checks exercise each configured package and inspect the generated config.
