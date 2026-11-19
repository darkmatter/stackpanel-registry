{
  description = "Consumer acceptance check for Stackpanel framework, tooling and cloud modules";

  inputs = {
    stackpanel.url = "github:darkmatter/stackpanel";
    nixpkgs.follows = "stackpanel/nixpkgs";
    nextjs.url = "path:../../modules/nextjs";
    astro.url = "path:../../modules/astro";
    remix.url = "path:../../modules/remix";
    nuxt.url = "path:../../modules/nuxt";
    oxlint.url = "path:../../modules/oxlint";
    playwright.url = "path:../../modules/playwright";
    fly.url = "path:../../modules/fly";
  };

  outputs =
    inputs:
    inputs.stackpanel.lib.mkFlake {
      inherit inputs;
      perSystem =
        {
          lib,
          pkgs,
          config,
          ...
        }:
        {
          checks.archetypes = import ./check.nix {
            inherit lib pkgs;
            inherit (config) legacyPackages;
          };
        };
    };
}
