{
  description = "Python language environment for the project dev shell.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Last revision before nixpkgs-python switched its CPython patches to 26.05.
    nixpkgs-python.url = "github:cachix/nixpkgs-python/17b47d6bf8086cff9957d5e82959a8ef63f72a80";
    nixpkgs-python.inputs.nixpkgs.follows = "nixpkgs";

    # Use the workspace reader and builders locked together by the backend set.
    pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";
    pyproject-build-systems.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.follows = "pyproject-build-systems/uv2nix";
    pyproject-nix.follows = "pyproject-build-systems/pyproject-nix";
  };

  outputs =
    {
      nixpkgs-python,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
      ...
    }:
    {
      stackpanelModuleMeta.followsNixpkgs = true;
      stackpanelModules.default = import ./nix/module.nix {
        inherit nixpkgs-python uv2nix pyproject-nix pyproject-build-systems;
      };
    };
}
