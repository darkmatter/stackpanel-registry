{
  description = "Solidity language environment for the project dev shell.";

  # Build the pinned upstream binary package with the consuming project's
  # pkgs. Its dev shell and CI inputs are not needed here.
  inputs.foundry = { url = "github:shazow/foundry.nix"; flake = false; };

  outputs = { foundry, ... }: {
    stackpanelModuleMeta.followsNixpkgs = false;
    stackpanelModules.default = import ./nix/module.nix { inherit foundry; };
  };
}
