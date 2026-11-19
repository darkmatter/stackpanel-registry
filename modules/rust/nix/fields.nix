sp: {
  enable = sp.bool {
    index = 1;
    default = false;
    description = "Build this Cargo binary and register Rust as its runtime.";
    ui = null; # Set by the runtime selector.
  };
  binaryName = sp.string {
    index = 2;
    optional = true;
    description = "Cargo binary target (--bin). Defaults to the Stackpanel app name.";
    ui.label = "Binary name";
  };
  packageName = sp.string {
    index = 3;
    optional = true;
    description = "Select a package in a Cargo workspace (--package).";
    ui.label = "Cargo package";
  };
  workspaceRoot = sp.string {
    index = 4;
    optional = true;
    description = "Project-relative directory containing the workspace Cargo.toml and Cargo.lock. Defaults to the app path.";
    example = ".";
    ui.label = "Cargo workspace root";
  };
  features = sp.string {
    index = 5;
    repeated = true;
    default = [ ];
    description = "Cargo features to enable for builds and tests.";
    ui = {
      label = "Cargo features";
      type = "FIELD_TYPE_JSON";
    };
  };
  defaultFeatures = sp.bool {
    index = 6;
    default = true;
    description = "Build with the crate's default feature set.";
    ui.label = "Default features";
  };
  doCheck = sp.bool {
    index = 7;
    default = true;
    description = "Run Cargo tests in the Nix build sandbox.";
    ui.label = "Run tests during build";
  };
}
