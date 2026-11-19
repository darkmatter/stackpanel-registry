{
  description = "Clojure language environment for the project dev shell.";

  inputs.java.url = "path:../java";

  outputs = { java, ... }: {
    stackpanelModuleMeta.followsNixpkgs = false;
    stackpanelModules.default = {
      imports = [
        ./nix/module.nix
        java.stackpanelModules.default
      ];
    };
  };
}
