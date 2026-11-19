package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

// A concrete edge names a node; a follows edge names an input path from the root.
type lockEdge struct {
	node    string
	follows []string
}

func (e *lockEdge) UnmarshalJSON(data []byte) error {
	if data[0] == '[' {
		if err := json.Unmarshal(data, &e.follows); err != nil {
			return err
		}
		for _, part := range e.follows {
			if part == "" {
				return fmt.Errorf("empty name in follows path %s", data)
			}
		}
		return nil
	}
	if err := json.Unmarshal(data, &e.node); err != nil || e.node == "" {
		return fmt.Errorf("expected a lock node name or follows path, got %s", data)
	}
	return nil
}

type lockNode struct {
	Inputs map[string]lockEdge
	Parent []string
	Locked *struct{ Type, Path, Dir, Owner, Repo string }
}

func checkLock(path string, modules []moduleInput) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var lock struct {
		Root  string
		Nodes map[string]*lockNode
	}
	if err := json.Unmarshal(data, &lock); err != nil {
		return fmt.Errorf("decode %s: %w", path, err)
	}
	root := lock.Nodes[lock.Root]
	if lock.Root == "" || root == nil {
		return fmt.Errorf("missing lock root node %q", lock.Root)
	}
	roots := make(map[string]string, len(modules))
	for _, m := range modules {
		name := "module-" + m.Slug
		key := root.Inputs[name].node
		if key == "" || lock.Nodes[key] == nil {
			return fmt.Errorf("root input %s must name an existing lock node, got %q", name, key)
		}
		roots[m.Slug] = key
	}
	for name := range root.Inputs {
		if slug, ok := strings.CutPrefix(name, "module-"); ok && roots[slug] == "" {
			return fmt.Errorf("unexpected module input %s in lock root", name)
		}
	}

	todo := make([]string, 0, len(roots))
	for slug, key := range roots {
		todo = append(todo, key)
		for dep, edge := range lock.Nodes[key].Inputs {
			if roots[dep] == "" || (len(edge.follows) == 1 && edge.follows[0] == "module-"+dep) {
				continue
			}
			n := lock.Nodes[edge.node]
			// Nix may anchor several sibling paths at the same checkout module.
			if n != nil && n.Locked != nil && len(n.Parent) == 1 {
				parent, ok := strings.CutPrefix(n.Parent[0], "module-")
				if ok && roots[parent] != "" && n.Locked.Type == "path" && n.Locked.Path == "../"+dep && n.Locked.Dir == "" {
					continue
				}
			}
			return fmt.Errorf("%s/%s did not resolve to the checkout sibling", slug, dep)
		}
	}

	// Do not traverse follows: the SDK can pin its own published registry modules.
	seen := make(map[string]bool)
	for len(todo) > 0 {
		key := todo[len(todo)-1]
		todo = todo[:len(todo)-1]
		if seen[key] {
			continue
		}
		seen[key] = true
		n := lock.Nodes[key]
		if n == nil || n.Locked == nil {
			return fmt.Errorf("candidate lock node %q is missing or has no locked source", key)
		}
		if n.Locked.Owner == "darkmatter" && n.Locked.Repo == "stackpanel-registry" {
			return fmt.Errorf("%s used the published registry in a candidate subtree", key)
		}
		for _, edge := range n.Inputs {
			if edge.node != "" {
				todo = append(todo, edge.node)
			}
		}
	}
	return nil
}
