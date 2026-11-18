{
  description = "Ruby language environment for the project dev shell.";

  inputs = {
    c.url = "path:../c";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { c, nixpkgs-ruby, ... }: {
    stackpanelModuleMeta.followsNixpkgs = true;
    stackpanelModules.default = {
      imports = [
        (import ./nix/module.nix { inherit nixpkgs-ruby; })
        c.stackpanelModules.default
      ];
    };
  };
}
