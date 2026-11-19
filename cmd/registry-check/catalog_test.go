package main

import (
	"encoding/json"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestCheckCatalog(t *testing.T) {
	// Exercise the actual catalog and schema, including any existing release
	// tags. Keep every mutation in a disposable local checkout.
	root := t.TempDir()
	git := func(t *testing.T, args ...string) string {
		t.Helper()
		cmd := exec.Command("git", append([]string{"-C", root, "-c", "user.name=Test", "-c", "user.email=test@localhost", "-c", "commit.gpgsign=false"}, args...)...)
		out, err := cmd.CombinedOutput()
		if err != nil {
			t.Fatalf("git %v: %v: %s", args, err, out)
		}
		return strings.TrimSpace(string(out))
	}
	source, err := filepath.Abs("../..")
	if err != nil {
		t.Fatal(err)
	}
	git(t, "clone", "--quiet", source, ".")
	original, err := os.ReadFile(filepath.Join(root, "registry.v1.json"))
	if err != nil {
		t.Fatal(err)
	}
	write := func(t *testing.T, name string, data []byte) {
		t.Helper()
		if err := os.WriteFile(filepath.Join(root, name), data, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	// Start each edit from the original so that cases do not share mutations.
	mutate := func(t *testing.T, change func(map[string]any)) {
		t.Helper()
		var doc map[string]any
		if err := json.Unmarshal(original, &doc); err != nil {
			t.Fatal(err)
		}
		change(doc["modules"].([]any)[0].(map[string]any))
		data, err := json.Marshal(doc)
		if err != nil {
			t.Fatal(err)
		}
		write(t, "registry.v1.json", data)
		write(t, "modules.json", data)
	}
	wantError := func(t *testing.T, part string) {
		t.Helper()
		inputs, err := checkCatalog(root)
		if len(inputs) != 0 || err == nil || !strings.Contains(err.Error(), part) {
			t.Fatalf("wanted rejection mentioning %q, got %v, %v", part, inputs, err)
		}
	}

	t.Run("alias must match bytes", func(t *testing.T) {
		write(t, "modules.json", append(original, '\n'))
		wantError(t, "modules.json")
	})
	t.Run("assert URI format in addition to pattern", func(t *testing.T) {
		mutate(t, func(m map[string]any) { m["homepage"] = "https://example.org/%zz" })
		wantError(t, "uri")
	})
	t.Run("latest release must pin the module", func(t *testing.T) {
		const tag = "registry-check-tests/candidate"
		git(t, "update-ref", "refs/tags/"+tag, "HEAD")
		var want moduleInput
		release := func(rev string) {
			mutate(t, func(m map[string]any) {
				versions := m["versions"].([]any)
				v := maps.Clone(versions[0].(map[string]any))
				want = moduleInput{Slug: m["slug"].(string), FollowsNixpkgs: !v["followsNixpkgs"].(bool)}
				v["version"], v["ref"], v["followsNixpkgs"] = tag, tag, want.FollowsNixpkgs
				delete(v, "flakePath") // The default export is valid for the latest version.
				delete(v, "rev")
				if rev != "" {
					v["rev"] = rev
				}
				m["latestVersion"], m["versions"] = tag, append(versions, v)
			})
		}
		release("")
		inputs, err := checkCatalog(root)
		if err != nil || len(inputs) == 0 || inputs[0] != want {
			t.Fatalf("tagged release: wanted latest input %+v, got %+v (%v)", want, inputs, err)
		}
		// The commit exists, but contains no files. It takes precedence over
		// the otherwise valid tag and must not pass an object-existence check.
		emptyCommit := git(t, "commit-tree", git(t, "mktree"), "-m", "before module")
		release(emptyCommit)
		wantError(t, "modules/"+want.Slug+"/flake.nix")
	})
}
