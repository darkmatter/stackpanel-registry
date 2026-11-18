// registry-check validates the catalog in the current registry checkout.
package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	catalogOnly := flag.Bool("catalog-only", false, "check the catalog and release pins without Nix")
	sdk := flag.String("sdk-checkout", "", "use a local Stackpanel Git checkout instead of SDK_REVISION")
	system := flag.String("system", "x86_64-linux", "Nix system for module and consumer checks")
	flag.Parse()
	if flag.NArg() != 0 {
		flag.Usage()
		os.Exit(2)
	}
	if err := run(*catalogOnly, *sdk, *system); err != nil {
		fmt.Fprintln(os.Stderr, "registry-check:", err)
		os.Exit(1)
	}
}

func run(catalogOnly bool, sdk, system string) error {
	root, err := os.Getwd()
	if err != nil {
		return err
	}
	modules, err := checkCatalog(root)
	if err != nil {
		return err
	}
	fmt.Printf("Catalog OK: %d modules\n", len(modules))
	if catalogOnly {
		return nil
	}
	return checkModules(root, modules, sdk, system)
}
