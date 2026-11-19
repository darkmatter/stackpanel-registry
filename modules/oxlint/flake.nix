{
  description = "Stackpanel per-app OxLint integration";
  outputs = _: { stackpanelModules.default = import ./nix/module.nix; };
}
