{
  description = "PHP language environment for the project dev shell.";

  # nix-phps uses unstable's generic PHP builder (including its PEAR PHAR)
  # and packages such as php86 which do not exist in host nixpkgs 25.11.
  inputs.phps.url = "github:fossar/nix-phps";

  outputs = { phps, ... }: {
    stackpanelModuleMeta.followsNixpkgs = false;
    stackpanelModules.default = import ./nix/module.nix { inherit phps; };
  };
}
