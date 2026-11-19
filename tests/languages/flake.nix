{
  description = "Evaluate versioned toolchains with only the language module inputs";
  inputs = {
    stackpanel.url = "github:darkmatter/stackpanel";
    nixpkgs.follows = "stackpanel/nixpkgs";
    php.url = "path:../../modules/php";
    python.url = "path:../../modules/python";
    python.inputs.nixpkgs.follows = "nixpkgs";
    ruby.url = "path:../../modules/ruby";
    ruby.inputs.nixpkgs.follows = "nixpkgs";
    solidity.url = "path:../../modules/solidity";
    terraform.url = "path:../../modules/terraform";
    zig.url = "path:../../modules/zig";
    zig.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs: inputs.stackpanel.lib.mkFlake {
    inherit inputs;
    perSystem = { config, pkgs, lib, ... }: {
      checks.language-inputs = import ./check.nix {
        inherit lib pkgs;
        pythonProject = inputs.python + "/tests/project";
        sp = config.legacyPackages.stackpanelFullConfig;
      };
    };
  };
}
