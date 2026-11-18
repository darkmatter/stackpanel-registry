{
  description = "Rust provider acceptance: build, editors, Linux image and NixOS service";

  inputs = {
    stackpanel.url = "github:darkmatter/stackpanel";
    nixpkgs.follows = "stackpanel/nixpkgs";
    rust.url = "path:../../modules/rust";
    rust.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, stackpanel, ... }@inputs:
    stackpanel.lib.mkFlake {
      inherit self inputs;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem = { pkgs, system, ... }: {
        checks.rust = import ./check.nix { inherit self pkgs system; };
      };
    };
}
