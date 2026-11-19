{
  description = "Crystal language environment for the project dev shell.";

  inputs.c.url = "path:../c";

  outputs = { c, ... }: {
    stackpanelModuleMeta.followsNixpkgs = false;
    stackpanelModules.default = {
      imports = [
        ./nix/module.nix
        c.stackpanelModules.default
      ];
    };
  };
}
