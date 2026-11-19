# Rust runtime

Enable `rust` to put Cargo, rustc, Clippy, rustfmt and rust-analyzer in the workspace shell. Select **Rust** in an app's Studio runtime card to configure its Cargo build. Enabling the workspace toolchain alone does not build any apps.

Install with `stack module install rust`, or add the flake manually:

```nix
inputs.rust.url = "github:darkmatter/stackpanel-registry?dir=modules/rust";
inputs.rust.inputs.nixpkgs.follows = "nixpkgs";
```

Stackpanel discovers `rust.stackpanelModules.default` and its Rust overlay. No separate consumer inputs for rust-overlay, Crane or crate2nix are necessary.

## Build a Cargo app

In a Stackpanel module:

```nix
{
  stackpanel.modules.rust.enable = true;
  stackpanel.apps.api = {
    path = "services/api";
    rust = {
      enable = true;
      binaryName = "api-server";  # Cargo [[bin]].name; defaults to the app key
    };
  };
}
```

Commit `Cargo.toml`, `Cargo.lock` and the source files. `nix build .#api` produces `result/bin/api-server`. The package is built with the same toolchain as the workspace; Cargo dependencies are vendored from the lockfile. Cargo tests run by default. For a multi-crate workspace, set `rust.workspaceRoot` to the project-relative directory containing the workspace lockfile (often `"."`) and `rust.packageName` to the member crate name. `rust.features`, `rust.defaultFeatures` and `rust.doCheck` control feature selection and tests. These options are editable in the `app:runtime` panel.

## Toolchain and editors

The default channel is `nixpkgs`. Existing `stackpanel.languages.rust.enable = true` configurations still select the module. Other workspace settings keep their `stackpanel.languages.rust` paths. For example:

```nix
stackpanel.languages.rust = {
  channel = "stable";             # also beta or nightly
  version = "latest";             # latest in the locked overlay, not at shell entry
  targets = [ "wasm32-unknown-unknown" ];
  components = [ "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" "rust-src" ];
};
```

Alternatively set `toolchainFile = ./rust-toolchain.toml` (or a legacy `rust-toolchain` file) and leave `channel`, `version` and `targets` unset. Include `rust-analyzer` in that file's components to use the toolchain's editor server, or override `lsp.package`. With `lsp.enable` on, both VS Code and Zed receive the executable path. Individual package overrides belong under `toolchain`; `toolchainPackage` is the assembled result.

You can set `rustflags` and `rustdocflags`, select **one** of `mold.enable`, `lld.enable`, `wild.enable`, or configure the Linux clang driver with `clangLinker.enable`. Nightly supports `cranelift.enable`, `cranelift.forceBuildScriptsLlvm` and `cranelift.excludePackages`. The latter manages only the affected package keys in `.cargo/config.toml`.

`config.stackpanel.languages.rust.import ./crate { }` retains the optional crate2nix import helper. It uses import-from-derivation; the standard per-app Crane build does not require this helper.

## Container or systemd

For the example above, set `stackpanel.apps.api.container.enable = true` and run `nix build .#container-api`. The Rust builder uses the app's **Linux** package, not a binary from the local shell; the consumer must expose packages for the configured Linux builder. The image runs `/app/server` unless you override the container startup command. Stackpanel's normal backend, port, registry and copy settings still apply.

For a NixOS deployment, configure the machine in Stackpanel's deployment inventory, then set:

```nix
stackpanel.apps.api.deployment = {
  enable = true;
  backend = "colmena";
  targets = [ "prod" ];
};
```

The generated systemd unit runs the target system's `api` package (`bin/api-server` here). No hard-coded store path, devshell wrapper or `cargo run` is needed. An explicit `deployment.command` overrides the runtime default.

The workspace toolchain configuration is adapted from [devenv's Rust module](https://github.com/cachix/devenv/blob/a73c5b84c9527760f009232988466763068f9f61/src/modules/languages/rust.nix), licensed under Apache-2.0.
