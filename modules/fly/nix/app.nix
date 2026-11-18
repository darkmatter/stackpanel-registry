{
  lib,
  cfg,
  fields,
  enabledHost,
  isFly,
}:
{ name, config, ... }:
let
  sp = lib.stackpanel.spField;
  inherit (config.deployment) container;
  override = field: attrs: (sp.asOption fields.${field}) // attrs;
in
{
  options.deployment = {
    fly = lib.mapAttrs (_: sp.asOption) fields // {
      appName = override "appName" { default = name; };
      region = override "region" { default = cfg.deployment.fly.defaultRegion; };
      cpuKind = override "cpuKind" {
        type = lib.types.enum [
          "shared"
          "performance"
        ];
      };
      autoStop = override "autoStop" {
        type = lib.types.enum [
          "off"
          "stop"
          "suspend"
        ];
      };
      cpus = override "cpus" { type = lib.types.ints.positive; };
      minMachines = override "minMachines" { type = lib.types.ints.unsigned; };
    };
    container = {
      type = lib.mkOption {
        type = lib.types.str;
        default = "bun";
        description = "Container builder ID.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Internal HTTP port.";
      };
      entrypoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Container startup command override.";
      };
    };
  };
  config = {
    deployment.backend = lib.mkIf (config.deployment.enable && enabledHost config) (
      lib.mkDefault "fly"
    );
    container = lib.mkIf (cfg.enable && cfg.modules.fly.enable && isFly config) {
      enable = lib.mkDefault true;
      type = lib.mkDefault container.type;
      name = lib.mkDefault config.deployment.fly.appName;
      registry = lib.mkDefault "docker://registry.fly.io/";
      port = lib.mkDefault container.port;
      startupCommand = lib.mkDefault container.entrypoint;
      env = lib.mapAttrs (_: lib.mkDefault) config.deployment.fly.env;
    };
  };
}
