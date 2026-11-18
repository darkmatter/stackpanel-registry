{ lib, pkgs }:
pkgs.runCommand "stackpanel-fly-ui" { nativeBuildInputs = [ pkgs.esbuild ]; } ''
  mkdir "$out"
  cp ${./index.html} "$out/index.html"
  cp ${./panel.css} "$out/panel.css"
  mkdir -p node_modules/@stackpanel
  ln -s ${lib.stackpanel.extensionSdk} node_modules/@stackpanel/extension-sdk
  cp ${./panel.ts} panel.ts
  esbuild panel.ts --bundle --platform=browser --format=iife --conditions=module \
    --outfile="$out/panel.js"
''
