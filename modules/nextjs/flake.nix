{
  description = "Next.js framework configuration and tasks for App Router and Pages Router";
  outputs = _: { stackpanelModules.default = import ./nix/module.nix; };
}
