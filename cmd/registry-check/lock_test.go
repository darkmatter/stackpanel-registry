package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCheckLock(t *testing.T) {
	// The SDK pins its own published copy of b, while a's b uses the checkout.
	const good = `{"root":"fixture","nodes":{
		"fixture":{"inputs":{"module-a":"a","module-b":"b","stackpanel":"sdk"}},
		"a":{"locked":{"type":"git","dir":"modules/a"},"inputs":{"b":"sibling","external":["stackpanel","b"]}},
		"b":{"locked":{"type":"git","dir":"modules/b"}},
		"sibling":{"parent":["module-b"],"locked":{"type":"path","path":"../b"}},
		"sdk":{"locked":{"type":"git"},"inputs":{"b":"published"}},
		"published":{"locked":{"type":"github","owner":"darkmatter","repo":"stackpanel-registry","dir":"modules/b"}}
	}}`
	for _, tc := range []struct{ name, old, replacement, want string }{
		{"common checkout parent and external follows", "", "", ""},
		{"direct sibling follows", `"b":"sibling"`, `"b":["module-b"]`, ""},
		{"same named SDK follows", `"b":"sibling"`, `"b":["stackpanel","b"]`, "a/b"},
		{"same named remote", `"b":"sibling"`, `"b":"published"`, "a/b"},
		{"wrong directory", `"../b"`, `"../a"`, "a/b"},
		{"nonempty subdirectory", `"path":"../b"`, `"path":"../b","dir":"extra"`, "a/b"},
		{"wrong checkout parent", `"parent":["module-b"]`, `"parent":["stackpanel"]`, "a/b"},
		{"published transitive dependency", `"parent":["module-b"]`, `"inputs":{"alias":"published"},"parent":["module-b"]`, "published registry"},
		{"dangling concrete dependency", `"external":["stackpanel","b"]`, `"external":"missing"`, "missing"},
		{"missing module", `"module-a":"a"`, `"other":"a"`, "module-a"},
		{"unexpected module", `"stackpanel":"sdk"`, `"stackpanel":"sdk","module-c":"b"`, "module-c"},
		{"root module follows", `"module-a":"a"`, `"module-a":["stackpanel","b"]`, "module-a"},
		{"malformed edge", `"external":["stackpanel","b"]`, `"external":null`, "lock node name or follows path"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			data := good
			if tc.old != "" {
				data = strings.Replace(good, tc.old, tc.replacement, 1)
				if data == good {
					t.Fatal("test mutation did not change fixture")
				}
			}
			path := filepath.Join(t.TempDir(), "flake.lock")
			if err := os.WriteFile(path, []byte(data), 0600); err != nil {
				t.Fatal(err)
			}
			err := checkLock(path, []moduleInput{{Slug: "a"}, {Slug: "b"}})
			if tc.want == "" && err != nil || tc.want != "" && (err == nil || !strings.Contains(err.Error(), tc.want)) {
				t.Fatalf("checkLock error = %v, want %q", err, tc.want)
			}
		})
	}
}
