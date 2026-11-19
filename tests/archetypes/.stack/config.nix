let
  site = id: {
    path = "sites/${id}";
    framework.${id}.enable = true;
    deployment = {
      enable = true;
      host = "cloudflare";
    };
  };
in
{
  name = "archetype-contract";
  enable = true;
  turbo.enable = true;
  git-hooks.enable = true;
  deployment.enable = true;
  apps = {
    docs = (site "nextjs") // {
      framework.nextjs = {
        enable = true;
        output = "export";
      };
      linting.oxlint = {
        enable = true;
        gitHook = true;
        rules.no-debugger = "error";
        paths = [ "src" ];
      };
    };
    blog = site "astro";
    shop = site "remix";
    landing = site "nuxt";
    api = {
      path = "services/api";
      deployment = {
        enable = true;
        host = "fly";
        fly = {
          appName = "archetype-smoke-api";
          region = "ams";
        };
      };
    };
  };
  modules.playwright.settings.packageJson = "sites/nextjs/package.json";
}
