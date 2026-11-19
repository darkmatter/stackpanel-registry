{
  description = "Zig language environment for the project dev shell.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Publish the zig-overlay selectors, but get both binaries from one release index.
    zig-flake.url = "github:silversquirl/zig-flake/compat";
    zig-flake.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { zig-flake, ... }: {
    stackpanelModuleMeta.followsNixpkgs = true;
    stackpanelModules.default = import ./nix/module.nix { inherit zig-flake; };
  };
}
