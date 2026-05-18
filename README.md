# stackpanel-flake-registry

[Nix flake registry](https://nix.dev/manual/nix/latest/command-ref/conf-file#conf-flake-registry) (v2) for **stackpanel**.

| Short ref | Resolves to |
|---|---|
| `stackpanel` | `github:darkmatter/stackpanel` |

## Use

### Per-user (`~/.config/nix/nix.conf`)

```ini
flake-registry = https://raw.githubusercontent.com/darkmatter/stackpanel-flake-registry/main/registry.json
```

### NixOS / nix-darwin

```nix
nix.settings.flake-registry =
  "https://raw.githubusercontent.com/darkmatter/stackpanel-flake-registry/main/registry.json";
```

### Per-invocation

```bash
nix --flake-registry https://raw.githubusercontent.com/darkmatter/stackpanel-flake-registry/main/registry.json \
    run stackpanel
```

## Add a flake

Append to `flakes[]` in [`registry.json`](registry.json), keep entries alphabetised by `from.id`, validate with `jq empty registry.json`.
