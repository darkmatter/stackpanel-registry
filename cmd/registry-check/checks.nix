inputs@{ stackpanel, ... }:
let
  fixture = builtins.fromJSON (builtins.readFile ./fixture.json);
  inherit (fixture) system;
  inherit (stackpanel.inputs) nixpkgs;
  validate =
    slug: followsNixpkgs:
    let
      candidate = inputs."module-${slug}";
      meta = candidate.stackpanelModuleMeta or { };
      pkgs = import nixpkgs {
        inherit system;
        overlays = meta.overlays or [ ];
      };
    in
    builtins.addErrorContext "validating registry module ${slug}" (
      assert
        followsNixpkgs == (meta.followsNixpkgs or false) && (!followsNixpkgs || candidate.inputs ? nixpkgs)
        || throw "catalog followsNixpkgs does not match the flake";
      assert stackpanel.lib.validateModule {
        inherit pkgs;
        module = candidate.stackpanelModules.default;
        moduleId = slug;
        inputs = stackpanel.inputs // {
          ${slug} = candidate;
        };
      };
      slug
    );
in
assert
  stackpanel ? lib.validateModule
  || throw ''
    The selected Stackpanel SDK does not export lib.validateModule.
    Set SDK_REVISION to a commit containing the module SDK, or use -sdk-checkout locally.
  '';
{
  checks.${system} = {
    # Realizing this output requires every catalog entry to pass validation.
    catalog = nixpkgs.legacyPackages.${system}.writeText "validated-modules" (
      builtins.concatStringsSep "\n" (nixpkgs.lib.mapAttrsToList validate fixture.followsNixpkgs)
    );
    inherit (inputs.test-rust.checks.${system}) rust;
    inherit (inputs.test-archetypes.checks.${system}) archetypes;
    inherit (inputs.test-languages.checks.${system}) language-inputs;
  };
}
