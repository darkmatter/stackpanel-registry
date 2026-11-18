# Adapted from cachix/devenv's languages/rust.nix (Apache-2.0).
{
  lib,
  pkgs,
  stack,
  cfg,
  toolchain,
}:
let
  platform = pkgs.stdenv.hostPlatform;
  triple = platform.rust.rustcTarget;
  clang = lib.getExe pkgs.clang;
  explicit = cfg.mold.enable || cfg.lld.enable || cfg.wild.enable;
  linker =
    if triple == "x86_64-unknown-linux-gnu" && !explicit then
      pkgs.writeShellScript "rust-clang-lld" ''
        exec ${clang} --ld-path=${pkgs.llvmPackages.bintools}/bin/ld.lld "$@"
      ''
    else
      clang;
  linkerFlags =
    lib.optional cfg.mold.enable "-C link-arg=-fuse-ld=mold"
    ++ lib.optional cfg.lld.enable "-C link-arg=-fuse-ld=lld"
    ++ lib.optionals cfg.wild.enable (
      [
        "-C linker-features=-lld"
        "-C link-arg=-B${pkgs.wild}/bin"
      ]
      ++ lib.optional platform.isAarch64 "-Z unstable-options"
    );
  flags = extra: lib.concatStringsSep " " (linkerFlags ++ lib.optional (extra != "") extra);
  analyzer = "${cfg.lsp.package}/bin/rust-analyzer";
  # Use this subset during sandboxed Cargo builds, too. Leave RUSTFLAGS unset
  # by default so Cargo doesn't ignore the project's .cargo/config.toml.
  buildEnv =
    lib.optionalAttrs cfg.clangLinker.enable {
      "CARGO_TARGET_${lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] triple)}_LINKER" =
        toString linker;
    }
    // lib.optionalAttrs (flags cfg.rustflags != "") { RUSTFLAGS = flags cfg.rustflags; }
    // lib.optionalAttrs (flags cfg.rustdocflags != "") { RUSTDOCFLAGS = flags cfg.rustdocflags; }
    // lib.optionalAttrs cfg.cranelift.enable {
      CARGO_UNSTABLE_CODEGEN_BACKEND = "true";
      CARGO_PROFILE_DEV_CODEGEN_BACKEND = "cranelift";
    }
    // lib.optionalAttrs cfg.cranelift.forceBuildScriptsLlvm {
      CARGO_PROFILE_DEV_BUILD_OVERRIDE_CODEGEN_BACKEND = "llvm";
    };
  linkerPackages =
    lib.optional cfg.clangLinker.enable pkgs.clang
    ++ lib.optional cfg.mold.enable pkgs.mold-wrapped
    ++ lib.optional cfg.lld.enable pkgs.llvmPackages.bintools
    ++ lib.optional cfg.wild.enable pkgs.wild;
in
{
  inherit buildEnv linkerPackages;
  # Rust requires C tooling for build scripts and linking. Supply it directly;
  # installing Rust doesn't require a second language module.
  packages = toolchain.validate (
    [
      cfg.toolchainPackage
      pkgs.stdenv.cc
      pkgs.gnumake
      pkgs.pkg-config
    ]
    ++ linkerPackages
    ++ lib.optional platform.isDarwin pkgs.libiconv
    ++ lib.optional cfg.lsp.enable cfg.lsp.package
  );
  config.stackpanel = {
    languages.rust = toolchain.config;
    devshell = {
      env = buildEnv // {
        RUST_SRC_PATH =
          if cfg.toolchain ? rust-src then
            "${cfg.toolchain.rust-src}/lib/rustlib/src/rust/library"
          else
            toString pkgs.rustPlatform.rustLibSrc;
      };
      hooks.main = [
        ''
          export CARGO_INSTALL_ROOT="$(${pkgs.coreutils}/bin/realpath --no-symlinks "$STACKPANEL_ROOT"/${lib.escapeShellArg stack.dirs.profile}/cargo-install)"
          export PATH="$PATH:$CARGO_INSTALL_ROOT/bin:''${CARGO_HOME:-$HOME/.cargo}/bin"
        ''
      ];
    };
    ide = lib.mkIf cfg.lsp.enable {
      vscode.settings-modules = [ { config."rust-analyzer.server.path" = lib.mkDefault analyzer; } ];
      zed.settings-modules = [ { config.lsp.rust-analyzer.binary.path = lib.mkDefault analyzer; } ];
    };
    git-hooks = {
      clippy = {
        packageOverrides = lib.genAttrs [ "cargo" "clippy" ] (_: lib.mkDefault cfg.toolchainPackage);
        settings.offline = lib.mkDefault false;
      };
      rustfmt.packageOverrides = lib.genAttrs [ "cargo" "rustfmt" ] (
        _: lib.mkDefault cfg.toolchainPackage
      );
    };
    files.entries.".cargo/config.toml" = lib.mkIf (cfg.cranelift.excludePackages != [ ]) {
      format = "toml";
      writer = "paths";
      source = "rust";
      module = "rust";
      ops = map (crate: {
        op = "set";
        path = [
          "profile"
          "dev"
          "package"
          crate
          "codegen-backend"
        ];
        value = "llvm";
      }) cfg.cranelift.excludePackages;
    };
  };
}
