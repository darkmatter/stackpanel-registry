{
  description = "Erlang language environment for the project dev shell.";

  outputs = _: {
    stackpanelModuleMeta.followsNixpkgs = false;
    stackpanelModules.default = import ./nix/module.nix;
  };
}
