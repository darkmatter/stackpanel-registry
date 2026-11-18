package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

//go:embed checks.nix
var checksNix []byte

var sdkRevision = regexp.MustCompile(`^(main|[0-9a-fA-F]{40})$`)

func checkModules(root string, modules []moduleInput, localSDK, system string) error {
	dir, err := os.MkdirTemp("", "stackpanel-registry-check-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(dir)
	if err := writeFixture(dir, root, modules, localSDK, system); err != nil {
		return err
	}
	if err := runNix(dir, "flake", "lock", "path:."); err != nil {
		return err
	}
	if err := checkLock(filepath.Join(dir, "flake.lock"), modules); err != nil {
		return err
	}
	// Only the selected system is declared. Check it even on a non-native host.
	return runNix(dir, "flake", "check", "--no-update-lock-file", "--all-systems", "--print-build-logs", "path:.")
}

func writeFixture(dir, root string, modules []moduleInput, localSDK, system string) error {
	follows := make(map[string]bool, len(modules))
	for _, m := range modules {
		follows[m.Slug] = m.FollowsNixpkgs
	}
	bootstrap := strings.Fields(os.Getenv("SDK_MODULE_INPUTS"))
	for _, slug := range bootstrap {
		if _, ok := follows[slug]; !ok {
			return fmt.Errorf("SDK_MODULE_INPUTS: unknown catalog slug %q", slug)
		}
	}

	var sdk string
	if localSDK != "" {
		source, err := checkoutSource(localSDK)
		if err != nil {
			return err
		}
		sdk = source.String()
	} else {
		revision := os.Getenv("SDK_REVISION")
		if revision == "" {
			revision = "main"
		}
		if !sdkRevision.MatchString(revision) {
			return fmt.Errorf("SDK_REVISION must be main or a full commit SHA")
		}
		sdk = "github:darkmatter/stackpanel/" + revision
	}
	registry, err := checkoutSource(root)
	if err != nil {
		return err
	}

	// Flake inputs must be literal declarations. Generate only those bindings;
	// the module checks themselves are ordinary Nix in checks.nix.
	var flake strings.Builder
	fmt.Fprintf(&flake, "{\n  inputs.stackpanel.url = %q;\n", sdk)
	for _, slug := range bootstrap {
		fmt.Fprintf(&flake, "  inputs.stackpanel.inputs.%q.follows = %q;\n", slug, "module-"+slug)
	}
	for _, m := range modules {
		name := "module-" + m.Slug
		fmt.Fprintf(&flake, "  inputs.%s.url = %q;\n", name, subflake(registry, "modules/"+m.Slug))
		if m.FollowsNixpkgs {
			fmt.Fprintf(&flake, "  inputs.%s.inputs.nixpkgs.follows = \"stackpanel/nixpkgs\";\n", name)
		}
	}
	for _, suite := range []string{"rust", "archetypes", "languages"} {
		fmt.Fprintf(&flake, "  inputs.test-%s.url = %q;\n  inputs.test-%s.inputs.stackpanel.follows = \"stackpanel\";\n", suite, subflake(registry, "tests/"+suite), suite)
	}
	flake.WriteString("  outputs = inputs: import ./checks.nix inputs;\n}\n")
	if err := os.WriteFile(filepath.Join(dir, "flake.nix"), []byte(flake.String()), 0600); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(dir, "checks.nix"), checksNix, 0600); err != nil {
		return err
	}
	config, err := json.Marshal(struct {
		System  string          `json:"system"`
		Follows map[string]bool `json:"followsNixpkgs"`
	}{system, follows})
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "fixture.json"), config, 0600)
}

func runNix(dir string, args ...string) error {
	cmd := exec.Command("nix", args...)
	cmd.Dir, cmd.Stdout, cmd.Stderr = dir, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("nix %s: %w", strings.Join(args, " "), err)
	}
	return nil
}

// Pin the checkout before assembling the fixture. For an uncommitted tree use
// its immutable store snapshot: Git filtering is preserved, and no lockfile
// ever needs --allow-dirty-locks or a path to a mutable working directory.
func checkoutSource(dir string) (url.URL, error) {
	abs, err := filepath.Abs(dir)
	if err != nil {
		return url.URL{}, err
	}
	source := url.URL{Scheme: "git+file", Path: filepath.ToSlash(abs)}
	cmd := exec.Command("nix", "flake", "prefetch", "--json", source.String())
	cmd.Stderr = os.Stderr
	data, err := cmd.Output()
	if err != nil {
		return url.URL{}, fmt.Errorf("snapshot checkout %s: %w", dir, err)
	}
	var snapshot struct {
		StorePath string               `json:"storePath"`
		Locked    struct{ Rev string } `json:"locked"`
	}
	if err := json.Unmarshal(data, &snapshot); err != nil {
		return url.URL{}, fmt.Errorf("decode nix flake prefetch: %w", err)
	}
	if snapshot.Locked.Rev != "" {
		source.RawQuery = url.Values{"rev": {snapshot.Locked.Rev}}.Encode()
		return source, nil
	}
	if !filepath.IsAbs(snapshot.StorePath) {
		return url.URL{}, fmt.Errorf("no store snapshot for %s", dir)
	}
	return url.URL{Scheme: "path", Opaque: snapshot.StorePath}, nil
}

func subflake(source url.URL, dir string) string {
	query := source.Query()
	query.Set("dir", dir)
	source.RawQuery = query.Encode()
	return source.String()
}
