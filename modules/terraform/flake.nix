{
  description = "Terraform language environment for the project dev shell.";

  # Upstream builds older Terraform releases with release-specific nixpkgs.
  # Keep that tested package graph rather than overriding it with the host.
  inputs.nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";

  outputs = { nixpkgs-terraform, ... }: {
    stackpanelModuleMeta.followsNixpkgs = false;
    stackpanelModules.default = import ./nix/module.nix { inherit nixpkgs-terraform; };
  };
}
