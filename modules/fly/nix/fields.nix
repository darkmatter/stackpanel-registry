{ lib }:
let
  sp = lib.stackpanel.spField;
  choices =
    values:
    map (value: {
      inherit value;
      label = value;
    }) values;
  regions = {
    iad = "Ashburn, Virginia";
    lax = "Los Angeles";
    ord = "Chicago";
    sea = "Seattle";
    ewr = "Secaucus, NJ";
    lhr = "London";
    ams = "Amsterdam";
    fra = "Frankfurt";
    nrt = "Tokyo";
    sin = "Singapore";
    syd = "Sydney";
  };
in
{
  appName = sp.string {
    index = 1;
    description = "Globally unique Fly app name. Defaults to the Stackpanel app key.";
    example = "acme-api";
    ui.label = "App name";
  };
  region = sp.string {
    index = 2;
    default = "iad";
    description = "Primary Fly region. Defaults to the project's defaultRegion.";
    ui = {
      label = "Region";
      type = sp.uiType.select;
      options = lib.mapAttrsToList (value: city: {
        inherit value;
        label = "${city} (${value})";
      }) regions;
    };
  };
  memory = sp.string {
    index = 3;
    default = "512mb";
    description = "RAM allocated to each Machine.";
    ui = {
      label = "Memory";
      type = sp.uiType.select;
      options = choices [
        "256mb"
        "512mb"
        "1gb"
        "2gb"
        "4gb"
        "8gb"
      ];
    };
  };
  cpuKind = sp.string {
    index = 4;
    default = "shared";
    description = "Shared or dedicated CPU cores.";
    ui = {
      label = "CPU type";
      type = sp.uiType.select;
      options = choices [
        "shared"
        "performance"
      ];
    };
  };
  cpus = sp.int32 {
    index = 5;
    default = 1;
    description = "Number of CPU cores per Machine.";
    ui.label = "CPUs";
  };
  autoStop = sp.string {
    index = 6;
    default = "suspend";
    description = "What Fly should do when a Machine is idle.";
    ui = {
      label = "Auto stop";
      type = sp.uiType.select;
      options = choices [
        "off"
        "stop"
        "suspend"
      ];
    };
  };
  autoStart = sp.bool {
    index = 7;
    default = true;
    description = "Start a stopped Machine when a request arrives.";
    ui.label = "Auto start";
  };
  minMachines = sp.int32 {
    index = 8;
    default = 0;
    description = "Minimum number of Machines running in the primary region.";
    ui.label = "Minimum Machines";
  };
  forceHttps = sp.bool {
    index = 9;
    default = true;
    description = "Redirect HTTP requests to HTTPS.";
    ui.label = "Force HTTPS";
  };
  env = sp.string {
    index = 10;
    mapKey = "string";
    default = { };
    description = "Public environment variables for fly.toml. Use Fly secrets for credentials.";
    ui = null;
  };
}
