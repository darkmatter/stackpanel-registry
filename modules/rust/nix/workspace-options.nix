# Adapted from cachix/devenv's languages/rust.nix (Apache-2.0).
{ lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  components = [
    "rustc"
    "cargo"
    "clippy"
    "rustfmt"
    "rust-analyzer"
  ];
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "stackpanel" "languages" "rust" "packages" ]
      [ "stackpanel" "languages" "rust" "toolchain" ]
    )
  ];

  options.stackpanel.languages.rust = {
    enable = lib.mkEnableOption "the Rust module (also selectable via stackpanel.modules.rust.enable)";
    components = mkOption {
      type = types.listOf types.str;
      default = components;
      description = "Rustup components to install; the native standard library is included by rust-overlay.";
    };
    targets = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional Rust target triples for rust-overlay channels.";
    };
    channel = mkOption {
      type = types.enum [
        "nixpkgs"
        "stable"
        "beta"
        "nightly"
      ];
      default = "nixpkgs";
      description = "Use packages from nixpkgs or an upstream Rust release channel.";
    };
    version = mkOption {
      type = types.str;
      default = "latest";
      description = "Channel release (stable) or date (beta/nightly) from the locked overlay.";
    };
    rustflags = mkOption {
      type = types.str;
      default = "";
      description = "Extra flags for rustc.";
    };
    rustdocflags = mkOption {
      type = types.str;
      default = "";
      description = "Extra flags for rustdoc.";
    };
    mold.enable = lib.mkEnableOption "the mold linker";
    lld.enable = lib.mkEnableOption "the LLVM lld linker";
    wild.enable = lib.mkEnableOption "the wild linker on Linux";
    clangLinker.enable = mkOption {
      type = types.bool;
      default = pkgs.stdenv.hostPlatform.isLinux;
      defaultText = lib.literalExpression "pkgs.stdenv.hostPlatform.isLinux";
      description = "Use clang as the linker driver; select lld on x86_64 GNU/Linux unless another linker is selected.";
    };
    cranelift = {
      enable = lib.mkEnableOption "the Cranelift codegen backend for nightly dev builds";
      forceBuildScriptsLlvm = lib.mkEnableOption "LLVM for build scripts and proc macros";
      excludePackages = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Force the LLVM backend for these crates in the development profile.";
      };
    };
    lsp = {
      enable = lib.mkEnableOption "rust-analyzer in the shell, VS Code and Zed" // {
        default = true;
      };
      package = mkOption {
        type = types.package;
        description = "Language server package. Defaults to rust-analyzer from the selected toolchain where available.";
      };
    };
    toolchain = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.package;
        options = lib.genAttrs components (
          component:
          mkOption {
            type = types.nullOr types.package;
            default = pkgs.${component};
            defaultText = lib.literalExpression "pkgs.${component}";
            description = "The ${component} component package.";
          }
        );
      };
      default = { };
      description = "Override individual component packages or define additional components (such as miri).";
    };
    toolchainFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a rust-toolchain or rust-toolchain.toml; replaces manual channel, version and target selection.";
    };
    toolchainPackage = mkOption {
      type = types.package;
      description = "Aggregated Rust toolchain used in the shell and for application builds.";
    };
    import = mkOption {
      type = types.functionTo (types.functionTo types.package);
      description = "Build a Cargo project with crate2nix and this toolchain: import ./crate { }. Uses import-from-derivation.";
    };
  };
}
