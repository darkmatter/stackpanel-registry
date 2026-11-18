{
  lib,
  pkgs,
  crane,
  toolchain,
  workspace,
  projectRoot,
}:
name: app:
let
  cfg = app.rust;
  binary = if cfg.binaryName == null then name else cfg.binaryName;
  relative = if cfg.workspaceRoot == null then app.path else cfg.workspaceRoot;
  source =
    assert lib.assertMsg (
      relative != ""
      && !lib.hasPrefix "/" relative
      && !(builtins.elem ".." (lib.splitString "/" relative))
    ) "stackpanel.apps.${name}.rust: Cargo workspace must be inside the project";
    "${projectRoot}/${relative}";
  craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
  args = [
    "--locked"
  ]
  ++ lib.optionals (cfg.packageName != null) [
    "--package"
    cfg.packageName
  ]
  ++ lib.optional (!cfg.defaultFeatures) "--no-default-features"
  ++ lib.optionals (cfg.features != [ ]) [
    "--features"
    (lib.concatStringsSep "," cfg.features)
  ];
in
assert lib.assertMsg (
  builtins.match "[a-zA-Z0-9_][a-zA-Z0-9_.-]*" binary != null
) "stackpanel.apps.${name}.rust: invalid Cargo binary name '${binary}'";
assert lib.assertMsg
  (builtins.pathExists (source + "/Cargo.toml") && builtins.pathExists (source + "/Cargo.lock"))
  "stackpanel.apps.${name}.rust: expected Cargo.toml and Cargo.lock at '${relative}'; set rust.workspaceRoot for workspace members";
craneLib.buildPackage {
  # Keep project assets used by include_bytes! and build.rs; a Rust-only
  # filter would silently remove them from the flake snapshot.
  src = lib.cleanSourceWith {
    src = source;
    filter =
      path: type:
      !(
        type == "directory"
        && builtins.elem (builtins.baseNameOf path) [
          ".git"
          "target"
        ]
      );
  };
  pname = name;
  inherit (cfg) doCheck;
  cargoExtraArgs = lib.escapeShellArgs args;
  cargoBuildExtraArgs = lib.escapeShellArgs [
    "--bin"
    binary
  ];
  env = workspace.buildEnv;
  nativeBuildInputs = workspace.linkerPackages ++ [ pkgs.pkg-config ];
  buildInputs = lib.optional pkgs.stdenv.hostPlatform.isDarwin pkgs.libiconv;
  meta.mainProgram = binary;
}
