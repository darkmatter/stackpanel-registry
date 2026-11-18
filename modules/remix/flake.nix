{
  description = "Remix framework configuration and tasks for Vite-based Remix apps";
  outputs = _: { stackpanelModules.default = import ./nix/module.nix; };
}
