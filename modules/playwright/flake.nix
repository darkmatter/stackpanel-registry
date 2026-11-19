{
  description = "Stackpanel Playwright adoption and end-to-end testing";
  outputs = _: { stackpanelModules.default = import ./nix/module.nix; };
}
