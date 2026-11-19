{
  description = "Astro framework configuration and tasks for static and server-rendered sites";
  outputs = _: { stackpanelModules.default = import ./nix/module.nix; };
}
