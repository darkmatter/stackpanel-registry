{
  description = "Nuxt framework configuration and tasks for Vue and Nitro apps";
  outputs = _: { stackpanelModules.default = import ./nix/module.nix; };
}
