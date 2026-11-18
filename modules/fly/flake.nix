{
  description = "Fly.io deployments and Studio panels for Stackpanel";

  outputs = { ... }: {
    lib.flyOidc = import ./nix/fly-oidc.nix;
    stackpanelModules.default = import ./nix/module.nix;
    stackpanelModuleMeta.followsNixpkgs = false;
  };
}
