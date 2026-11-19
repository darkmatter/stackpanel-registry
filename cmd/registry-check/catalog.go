package main

import (
	"bytes"
	"fmt"
	"io/fs"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"github.com/santhosh-tekuri/jsonschema/v6"
)

type moduleInput struct {
	Slug           string
	FollowsNixpkgs bool
}

// Read values from the same document the schema validated. In particular,
// do not decode the bytes again into structs: encoding/json merges duplicate
// object fields into structs, which can resurrect a superseded release pin.
type catalogObject map[string]any

func object(v any) catalogObject {
	o, _ := v.(map[string]any)
	return o
}

func (o catalogObject) text(key string) string {
	s, _ := o[key].(string)
	return s
}

func (o catalogObject) array(key string) []any {
	a, _ := o[key].([]any)
	return a
}

const officialRepo = "darkmatter/stackpanel-registry"

func checkCatalog(root string) ([]moduleInput, error) {
	data, err := os.ReadFile(filepath.Join(root, "registry.v1.json"))
	if err != nil {
		return nil, err
	}
	alias, err := os.ReadFile(filepath.Join(root, "modules.json"))
	if err != nil {
		return nil, err
	}
	if !bytes.Equal(data, alias) {
		return nil, fmt.Errorf("modules.json must be a byte-identical copy of registry.v1.json")
	}

	// Validate the original JSON (including slug, ref and rev patterns) before
	// using any catalog values in filesystem paths or Git object expressions.
	schemaPath, err := filepath.Abs(filepath.Join(root, "registry.v1.schema.json"))
	if err != nil {
		return nil, err
	}
	compiler := jsonschema.NewCompiler()
	compiler.DefaultDraft(jsonschema.Draft2020)
	compiler.AssertFormat()
	schemaURL := url.URL{Scheme: "file", Path: filepath.ToSlash(schemaPath)}
	schema, err := compiler.Compile(schemaURL.String())
	if err != nil {
		return nil, fmt.Errorf("compile registry.v1.schema.json: %w", err)
	}
	if schema.DraftVersion != 2020 {
		return nil, fmt.Errorf("registry.v1.schema.json must use Draft 2020-12")
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("decode registry.v1.json: %w", err)
	}
	if err := schema.Validate(doc); err != nil {
		return nil, fmt.Errorf("invalid registry.v1.json: %w", err)
	}
	modules := object(doc).array("modules")
	if len(modules) == 0 {
		return nil, fmt.Errorf("registry.v1.json contains no modules")
	}

	seen := make(map[string]bool, len(modules))
	inputs := make([]moduleInput, 0, len(modules))
	for _, raw := range modules {
		m := object(raw)
		id, slug := m.text("id"), m.text("slug")
		if id != slug || seen[slug] {
			return nil, fmt.Errorf("ambiguous module id %q, slug %q: IDs and slugs must match and be unique", id, slug)
		}
		seen[slug] = true
		input, err := checkModule(root, slug, m)
		if err != nil {
			return nil, fmt.Errorf("module %q: %w", slug, err)
		}
		inputs = append(inputs, input)
	}
	flakes, err := fs.Glob(os.DirFS(root), "modules/*/flake.nix")
	if err != nil {
		return nil, err
	}
	for _, flake := range flakes {
		slug := path.Base(path.Dir(flake))
		if !seen[slug] {
			return nil, fmt.Errorf("%s has no entry in registry.v1.json", flake)
		}
		if err := requireRegularFile(filepath.Join(root, flake)); err != nil {
			return nil, err
		}
		delete(seen, slug)
	}
	for slug := range seen {
		return nil, fmt.Errorf("catalog entry %q has no modules/%s/flake.nix", slug, slug)
	}
	return inputs, nil
}

func checkModule(root, slug string, m catalogObject) (moduleInput, error) {
	dir := "modules/" + slug
	if want := "https://github.com/" + officialRepo + "/tree/main/" + dir; m["homepage"] != want {
		return moduleInput{}, fmt.Errorf("homepage must be %q", want)
	}
	if readme, ok := m["readmeUrl"]; ok {
		if want := "https://raw.githubusercontent.com/" + officialRepo + "/main/" + dir + "/README.md"; readme != want {
			return moduleInput{}, fmt.Errorf("readmeUrl must be %q", want)
		}
		if err := requireRegularFile(filepath.Join(root, dir, "README.md")); err != nil {
			return moduleInput{}, err
		}
	}
	versions := m.array("versions")
	seen := make(map[string]bool, len(versions))
	latest := m.text("latestVersion")
	input := moduleInput{Slug: slug}
	for _, raw := range versions {
		v := object(raw)
		version := v.text("version")
		if seen[version] {
			return moduleInput{}, fmt.Errorf("duplicate version %q", version)
		}
		seen[version] = true
		if want := "github:" + officialRepo + "?dir=" + dir; v["flakeUrl"] != want {
			return moduleInput{}, fmt.Errorf("version %q: flakeUrl must be %q", version, want)
		}
		if version == latest {
			if export, ok := v["flakePath"]; ok && export != "stackpanelModules.default" {
				return moduleInput{}, fmt.Errorf("latest version %q must export stackpanelModules.default", version)
			}
			input.FollowsNixpkgs, _ = v["followsNixpkgs"].(bool)
		}
		if version == "main" {
			if v["ref"] != "main" {
				return moduleInput{}, fmt.Errorf("development version main requires ref main")
			}
		} else if err := checkPin(root, dir+"/flake.nix", v.text("rev"), v.text("ref")); err != nil {
			return moduleInput{}, fmt.Errorf("version %q: %w", version, err)
		}
		deps := map[string]bool{slug: true}
		for _, rawDep := range v.array("flakeInputs") {
			name := object(rawDep).text("name")
			if deps[name] {
				return moduleInput{}, fmt.Errorf("version %q: colliding input %q", version, name)
			}
			deps[name] = true
		}
	}
	if !seen[latest] {
		return moduleInput{}, fmt.Errorf("latestVersion %q is not in versions", latest)
	}
	return input, nil
}

func requireRegularFile(name string) error {
	info, err := os.Stat(name)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("%s is not a regular file", name)
	}
	return nil
}

func checkPin(root, flake, pin, ref string) error {
	if pin == "" {
		if ref == "" || ref == "main" {
			return fmt.Errorf("release needs a commit rev or an existing tag ref")
		}
		if !fs.ValidPath(ref) {
			return fmt.Errorf("invalid release tag path %q", ref)
		}
		// Resolve the exact tag, not a branch that happens to have its name.
		out, err := exec.Command("git", "-C", root, "show-ref", "--verify", "--hash", "--", "refs/tags/"+ref).Output()
		if err != nil {
			return fmt.Errorf("cannot resolve release tag %q: %w", ref, err)
		}
		pin = strings.TrimSpace(string(out))
	} else {
		// A hex string of the other supported hash width can still be a ref
		// name (or an abbreviated hash). A rev must be the commit ID itself.
		out, err := exec.Command("git", "-C", root, "rev-parse", "--verify", "--end-of-options", pin+"^{commit}").Output()
		if err != nil {
			return fmt.Errorf("cannot resolve release commit %q: %w", pin, err)
		}
		if !strings.EqualFold(strings.TrimSpace(string(out)), pin) {
			return fmt.Errorf("rev %q is not the full commit ID", pin)
		}
	}
	out, err := exec.Command("git", "-C", root, "cat-file", "-t", "--", pin+"^{commit}:"+flake).CombinedOutput()
	if err != nil {
		return fmt.Errorf("checking %s at %s: %w: %s", flake, pin, err, bytes.TrimSpace(out))
	}
	if string(out) != "blob\n" {
		return fmt.Errorf("%s at %s must be a file (got %s)", flake, pin, bytes.TrimSpace(out))
	}
	return nil
}
