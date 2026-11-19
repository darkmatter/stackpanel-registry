# Adapted from cachix/devenv's languages/rust.nix (Apache-2.0).
{
  lib,
  pkgs,
  cfg,
  rust-overlay,
  crate2nix,
}:
let
  fromFile = cfg.toolchainFile != null;
  fromOverlay = !fromFile && cfg.channel != "nixpkgs";
  rustBin = pkgs.rust-bin or (rust-overlay.lib.mkRustBin { } pkgs.buildPackages);
  channel = rustBin.${cfg.channel};
  release =
    channel.${cfg.version}
      or (throw "Rust ${cfg.channel} ${cfg.version} is not in the locked rust-overlay");
  native = pkgs.stdenv.hostPlatform.rust.rustcTarget;
  upstream =
    release._components.${native}
      or (throw "Rust ${cfg.channel} ${cfg.version} is not available for ${native}");
  components = cfg.components ++ lib.optional cfg.cranelift.enable "rustc-codegen-cranelift-preview";
  getComponent =
    name: cfg.toolchain.${name} or (throw "No Rust component '${name}' in the selected toolchain");
  standardLibraries = map (
    target:
    release._components.${target}.rust-std
      or (throw "No rust-std for '${target}' in Rust ${cfg.channel} ${cfg.version}")
  ) (lib.unique ([ native ] ++ cfg.targets));

  # The overlay's public profiles can add extensions but cannot substitute a
  # user-supplied component. Reuse its aggregation/patching of the sysroot.
  aggregate = pkgs.callPackage (rust-overlay + "/lib/mk-aggregated.nix") { };
  package =
    if fromFile then
      rustBin.fromRustupToolchainFile cfg.toolchainFile
    else if fromOverlay then
      aggregate {
        pname = "rust-${cfg.channel}";
        inherit (release._manifest) version date;
        selectedComponents = map getComponent components ++ standardLibraries;
      }
    else
      pkgs.symlinkJoin {
        name = "rust-toolchain-nixpkgs";
        paths = map getComponent components;
      };
  validate =
    value:
    assert lib.assertMsg (
      !cfg.cranelift.enable || cfg.channel == "nightly"
    ) "Rust Cranelift requires channel = \"nightly\".";
    assert lib.assertMsg (
      lib.count lib.id [
        cfg.mold.enable
        cfg.lld.enable
        cfg.wild.enable
      ] <= 1
    ) "Select at most one Rust linker (mold, lld, wild).";
    assert lib.assertMsg (
      !cfg.wild.enable || pkgs.stdenv.hostPlatform.isLinux
    ) "The wild linker requires Linux.";
    assert lib.assertMsg (
      !fromFile || (cfg.channel == "nixpkgs" && cfg.version == "latest" && cfg.targets == [ ])
    ) "Rust toolchainFile cannot be combined with manual channel, version or targets.";
    assert lib.assertMsg (
      cfg.channel != "nixpkgs" || (cfg.targets == [ ] && cfg.version == "latest")
    ) "Rust version and extra targets require an upstream channel.";
    value;
in
{
  inherit validate;
  config = {
    toolchain = lib.mkIf fromOverlay (
      lib.mapAttrs (_: lib.mkDefault) (removeAttrs upstream [ "rust" ])
    );
    toolchainPackage = lib.mkDefault (validate package);
    lsp.package = lib.mkDefault (
      if fromFile then
        cfg.toolchainPackage
      else if fromOverlay && !(upstream ? rust-analyzer) then
        pkgs.rust-analyzer
      else
        cfg.toolchain.rust-analyzer
    );
    import =
      path: args:
      let
        tools = pkgs.callPackage (crate2nix + "/tools.nix") { };
        manifest = builtins.fromTOML (builtins.readFile (path + "/Cargo.toml"));
        cargoNix = tools.generatedCargoNix {
          src = path;
          name = args.packageName or (manifest.package.name or (builtins.baseNameOf (toString path)));
          cargo = cfg.toolchainPackage;
        };
        project = pkgs.callPackage cargoNix {
          buildRustCrateForPkgs =
            targetPkgs:
            targetPkgs.buildRustCrate.override {
              rustc = cfg.toolchainPackage;
              cargo = cfg.toolchainPackage;
            };
        };
      in
      project.rootCrate.build.override (removeAttrs args [ "packageName" ]);
  };
}
