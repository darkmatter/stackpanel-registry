{
  self,
  pkgs,
  system,
}:
let
  sp = self.legacyPackages.${system}.stackpanelFullConfig;
  files = sp.files.entries;
  packages = self.packages.${system};
  linux = self.packages.x86_64-linux;
  target = self.packages.aarch64-linux.example;
  service = self.nixosConfigurations.test.config.systemd.services.example;
  analyzer = "${sp.languages.rust.lsp.package}/bin/rust-analyzer";
in
assert sp.appRuntimes.rust.module == "rust" && sp.panels.rust-runtime.slot == "app:runtime";
assert sp.apps.example.container.type == "rust";
# Even an image requested from the Darwin output must embed the Linux build.
assert self.packages.aarch64-darwin.container-example.drvPath == linux.container-example.drvPath;
# The NixOS machine intentionally does not match the image architecture.
assert service.serviceConfig.ExecStart == "${target}/bin/demo-server";
pkgs.runCommand "rust-provider-acceptance" { nativeBuildInputs = [ pkgs.jq ]; } ''
  test "$(${packages.example}/bin/demo-server)" = 'Stackpanel external Rust provider'
  test -x ${analyzer}
  jq -e --arg p ${analyzer} '."rust-analyzer.server.path" == $p' ${files.".vscode/settings.json".drv}
  jq -e --arg p ${analyzer} '.lsp."rust-analyzer".binary.path == $p' ${files.".zed/settings.json".drv}
  ${pkgs.lib.optionalString (system == "x86_64-linux") ''
    ${pkgs.python3}/bin/python3 ${./check-image.py} ${linux.container-example} ${linux.example}/bin/demo-server
  ''}
  touch "$out"
''
