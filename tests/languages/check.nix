{ lib, pkgs, sp, pythonProject }:
let
  langs = sp.languages;
  # Force the actual derivations, including their input graph. Don't build
  # every interpreter or download a Foundry binary just to test resolution.
  drv = p: assert lib.isDerivation p; builtins.unsafeDiscardStringContext p.drvPath;
  selected = {
    php = langs.php.package;
    composer = langs.php.packages.composer;
    ruby = langs.ruby.package;
    bundler = langs.ruby.bundler.package;
    rubyLsp = langs.ruby.lsp.package;
    terraform = langs.terraform.package;
    foundry = langs.solidity.foundry.package;
    python = langs.python.package;
    pythonEnv = langs.python.import pythonProject { };
    zig = langs.zig.package;
    zls = langs.zig.lsp.package;
  };
in
assert lib.all (id: sp.modules.${id}.flakeInputs == [ ]) [ "php" "python" "ruby" "solidity" "terraform" "zig" ];
assert selected.php.version == "7.4.33" && selected.composer.version == "2.10.3";
assert toString selected.ruby.version == "3.2.1" && selected.rubyLsp.gems.solargraph.version == "0.58.1";
assert selected.terraform.version == "1.5.7";
assert selected.python.python.version == "3.11.18" && selected.pythonEnv.name == "stackpanel-python-fixture-env";
assert selected.zig.version == "0.15.1" && selected.zls.version == "0.15.1";
assert selected.foundry.pname == "foundry";
pkgs.writeText "registry-language-inputs.json" (builtins.toJSON (builtins.mapAttrs (_: drv) selected))
