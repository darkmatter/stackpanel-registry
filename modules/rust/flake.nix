{
  description = "Rust toolchains and Cargo applications for Stackpanel";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    crane.url = "github:ipetkov/crane/v0.23.4"; # Supports the Stackpanel nixpkgs 25.11 baseline.
    # Only tools.nix is needed; don't lock crate2nix's own CI and devshell.
    crate2nix.url = "github:nix-community/crate2nix";
    crate2nix.flake = false;
  };

  outputs =
    {
      rust-overlay,
      crane,
      crate2nix,
      ...
    }:
    {
      stackpanelModuleMeta = {
        overlays = [ rust-overlay.overlays.default ];
        followsNixpkgs = true;
      };
      stackpanelModules.default = import ./nix/module.nix { inherit rust-overlay crane crate2nix; };
    };
}
