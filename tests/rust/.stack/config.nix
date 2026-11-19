{
  enable = true;
  name = "rust-consumer";
  modules.rust.enable = true;
  ide = {
    enable = true;
    vscode = {
      enable = true;
      output-mode = "settingsJson";
    };
    zed = {
      enable = true;
      output-mode = "dotZed";
    };
  };
  # A local archive that can be inspected without Docker or a registry.
  containers.settings.backend = "dockerTools";
  deployment.machines.test = {
    host = "unused.invalid";
    system = "aarch64-linux";
  };
  apps.example = {
    path = "crate";
    rust = {
      enable = true;
      binaryName = "demo-server";
    };
    container.enable = true;
    deployment = {
      enable = true;
      backend = "colmena";
      targets = [ "test" ];
    };
  };
}
