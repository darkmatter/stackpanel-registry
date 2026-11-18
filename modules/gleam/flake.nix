{
  description = "Gleam language environment for the project dev shell.";

  inputs.erlang.url = "path:../erlang";

  outputs = { erlang, ... }: {
    stackpanelModuleMeta.followsNixpkgs = false;
    stackpanelModules.default = {
      imports = [
        ./nix/module.nix
        erlang.stackpanelModules.default
      ];
    };
  };
}
