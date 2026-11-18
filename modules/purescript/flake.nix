{
  description = "PureScript language environment for the project dev shell.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.purescript-overlay.url = "github:thomashoneyman/purescript-overlay";
  inputs.purescript-overlay.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { purescript-overlay, ... }: {
    stackpanelModuleMeta.followsNixpkgs = true;
    stackpanelModules.default = import ./nix/module.nix { defaultOverlay = purescript-overlay; };
  };
}
