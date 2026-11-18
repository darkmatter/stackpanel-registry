# Toolchain options adapted from cachix/devenv a73c5b84c9527760f009232988466763068f9f61.
{ zig-flake }:
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.stackpanel.languages.zig;

  system = pkgs.stdenv.hostPlatform.system;
  zig = zig-flake.packages.${system}.${cfg.version} or (throw ''
    stackpanel.languages.zig.version: no Zig `${cfg.version}` for ${system} in the locked zig-flake.
    Select an available exact release (for example `0.15.2`), or leave version unset to use nixpkgs.
  '');

  # Old ZLS flakes build with different overlays (some even pin a Zig nightly).
  # Use the paired release binary instead of rebuilding ZLS or guessing a tag.
  zlsRelease = zig-flake.releases.${cfg.version}._zls or null;
  zls =
    if zlsRelease != null && zlsRelease ? ${system}
      # Historical nightlies without a recorded pair can inherit a *stable*
      # same-minor fallback from zig-flake; that isn't a tested nightly pair.
      && (lib.hasInfix "-dev." zig.version == lib.hasInfix "-dev." zlsRelease._version)
    then zig.zls
    else throw ''
      stackpanel.languages.zig: no compatible ZLS for Zig ${zig.version} on ${system} in the locked zig-flake.
      Set lsp.enable = false for compiler-only use, or set lsp.package to a compatible server.
    '';

  profileReady =
    config.stackpanel.enable
    && config.stackpanel.devshell.profile.enable
    && config.stackpanel.devshell.packages != [ ];
in
{
  key = "stackpanel-registry:zig";

  options.stackpanel.languages.zig = {
    enable = lib.mkEnableOption "tools for Zig development";

    version = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        With `null`, use the nixpkgs Zig and ZLS packages. Otherwise select an exact key
        from the module's locked [zig-flake](https://github.com/silversquirl/zig-flake/tree/compat):
        a release such as `0.15.1`, `default` (latest stable at the pin), `master`, or an
        available `master-YYYY-MM-DD`. Missing patches are errors, not minor-version aliases.

        With LSP enabled, use the release's paired ZLS binary: stable Zig uses the same
        major/minor ZLS line (patches can differ); nightlies need a recorded nightly pair.
        No consumer `zig-overlay` or `zls` flake input is needed. If there is no server for
        the release and platform, disable LSP or set `stackpanel.languages.zig.lsp.package`.
      '';
      example = "0.15.1";
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = "Which package of Zig to use.";
      default = pkgs.zig;
      defaultText = lib.literalExpression "pkgs.zig";
    };

    lsp = {
      enable = lib.mkEnableOption "Zig Language Server" // {
        default = true;
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.zls;
        defaultText = lib.literalExpression "pkgs.zls";
        description = "The Zig language server package to use.";
      };
    };
  };

  imports = [
    (lib.mkRenamedOptionModule
      [ "stackpanel" "languages" "zig" "zls" "package" ]
      [ "stackpanel" "languages" "zig" "lsp" "package" ]
    )
    (lib.stackpanel.mkModule {
      name = "zig";
      meta = {
        name = "Zig";
        description = "Zig language environment for the project dev shell.";
        category = "language";
      };
      source = {
        type = "flake-input";
        flakeInput = "zig";
      };
      enablePath = "languages.zig.enable";
      configPath = "languages.zig";
      features.packages = true;
      packages =
        _:
        [
          cfg.package
        ]
        ++ lib.optional cfg.lsp.enable cfg.lsp.package;
      config = _: {
        stackpanel.languages.zig.package = lib.mkIf (cfg.version != null) zig;
        stackpanel.languages.zig.lsp.package = lib.mkIf (cfg.version != null && cfg.lsp.enable) (
          lib.mkDefault zls
        );

        stackpanel.devshell.hooks.main = [
          (
            if config.stackpanel.devshell.env ? ZIG_GLOBAL_CACHE_DIR then
              ''export ZIG_GLOBAL_CACHE_DIR="${config.stackpanel.devshell.env.ZIG_GLOBAL_CACHE_DIR}"''
            else
              "unset ZIG_GLOBAL_CACHE_DIR"
          )
        ];

        stackpanel.devshell.env = {
          DEVENV_ROOT = ".";
          DEVENV_STATE = config.stackpanel.dirs.profile;
          DEVENV_RUNTIME = "${config.stackpanel.dirs.profile}/run";
          DEVENV_PROFILE = lib.mkIf profileReady (toString config.stackpanel.devshell.profile.package);
        };
      };
    })
  ];
}
