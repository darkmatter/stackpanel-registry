# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.dotnet;
  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:dotnet";

  options.stackpanel.languages.dotnet = {
    enable = lib.mkEnableOption "tools for .NET development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dotnetCorePackages.sdk_8_0;
      defaultText = lib.literalExpression "pkgs.dotnet-sdk";
      description = "The .NET SDK package to use.";
    };

    lsp = {
      enable = lib.mkEnableOption ".NET Language Server" // {
        # csharp-ls crashes on aarch64-darwin due to missing code signatures
        # https://github.com/razzmatazz/csharp-language-server/issues/211
        default = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.csharp-ls;
        defaultText = lib.literalMD "`true` if csharp-ls is available on the host platform, `false` otherwise";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.csharp-ls;
        defaultText = lib.literalExpression "pkgs.csharp-ls";
        description = "The .NET language server package to use.";
      };
    };
  };

  imports = [
    (lib.stackpanel.mkModule {
      name = "dotnet";
      meta = {
        name = ".NET";
        description = ".NET language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "dotnet";
      };
      enablePath = "languages.dotnet.enable";
      configPath = "languages.dotnet";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
          DOTNET_ROOT = "${
            if lib.hasAttr "unwrapped" cfg.package then cfg.package.unwrapped else cfg.package
          }/share/dotnet";
        };
      };
    })
  ];
}
