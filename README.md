# Stackpanel registry

This repository serves two different registries. [registry.v1.json](registry.v1.json) is the **Stackpanel module catalog**; [registry.json](registry.json) is the **Nix v2 flake registry** that maps the short name `stackpanel` to `github:darkmatter/stackpanel`. They are not interchangeable.

## Using the module catalog

Stackpanel's default source is <https://raw.githubusercontent.com/darkmatter/stackpanel-registry/main/registry.v1.json>. Each module is a real flake under [`modules/`](modules/). For example, the `oxlint` input is `github:darkmatter/stackpanel-registry?dir=modules/oxlint`, exporting `stackpanelModules.default`. Stackpanel uses the catalog slug as the consumer's input name; the consumer's `flake.lock` pins the resolved code.

To host a registry, serve a JSON document matching [registry.v1.schema.json](registry.v1.schema.json) at a direct HTTP(S) URL. The same schema applies to static files and API responses. Return an `ETag` and honor `If-None-Match` with `304 Not Modified` to avoid retransmitting unchanged catalogs and READMEs.

Stackpanel searches `stackpanel.registries` from the project first, then `registries` from machine config. Each is an ordered list of **index URLs**; the first match by ID or slug wins. Explicit sources replace the default: include the official URL yourself to search both. A broken higher-priority source is an error, not permission to install a same-named module from a lower-priority registry.

For private registries, list the source under `registries` in `~/.config/stackpanel/config.yaml`. Set `registryHeaders` **only in that machine config**, keyed by the exact index URL. Protect the file as a credential. Do not put tokens in source URLs, README links or project Nix. Credentials require HTTPS (except for loopback development). The client uses these headers for that index and its same-origin README requests only; it does not follow redirects.

The agent keeps validated responses for an hour in `$XDG_CACHE_HOME/stackpanel/registry` (default `~/.cache/stackpanel/registry`). After expiry it revalidates, preferring a previous validated response on connectivity errors or upstream 5xx. Only the official index (including its `modules.json` alias) has an embedded offline snapshot. Schema errors, authorization failures and 404s are not treated as offline responses. READMEs are optional and cached separately; they are never replaced by invented text.
If the cache directory is unwritable, successfully fetched or revalidated responses remain available for the current request.

## Publishing or updating a module

1. Add `modules/<slug>/flake.nix` exposing `stackpanelModules.default`. Register the module with ID `<slug>`. Use a stable, lowercase, hyphen-separated slug. Add a `README.md` if the catalog advertises one.
   Keep intra-registry dependencies in the same source tree so a consumer pin or a PR checkout does not silently import a sibling from the published `main`.
2. Update `registry.v1.json`. The envelope is `{ "schemaVersion": 1, "modules": [...] }`. Each entry includes searchable display metadata and `latestVersion` naming exactly one entry in `versions`. Each version specifies the remote `flakeUrl`, `followsNixpkgs` and an explicit `flakeInputs` array of **consumer** dependencies. Only set `followsNixpkgs` if the module declares that input. `flakePath` is a dotted output path (normally `stackpanelModules.default`), not a Nix expression.
   The initial catalog advertises `main`, a rolling development channel, not a numbered release. For a release such as `0.1.0`, merge the module code first, then use its **existing commit SHA** as `rev` (preferred) or an existing protected release tag as `ref`. CI rejects mutable branch-only releases and pins that do not contain the module. Never invent a tag or try to include the catalog commit's own SHA in its contents.
3. Copy `registry.v1.json` to `modules.json`, its byte-identical compatibility endpoint. CI validates the JSON Schema, IDs, versions, README targets, one-to-one correspondence with `modules/*/flake.nix`, and each module using `stackpanel.lib.validateModule` against the checked-out flake (not the published version).
   CI also builds the Linux consumer checks from `tests/rust`, `tests/archetypes`, and `tests/languages` against the same SDK revision used for catalog validation. The language check exercises options that require extra implementation inputs; if a module owns those inputs privately, they do not belong in the catalog's `flakeInputs`.
4. When releasing a new official snapshot, update the Stackpanel checkout from this repository:

   ```sh
   cp registry.v1.json ../stackpanel/apps/stackpanel-go/internal/registry/snapshot.json
   cp registry.v1.schema.json ../stackpanel/apps/stackpanel-go/internal/registry/
   ```

   Never publish an incompatible contract change under the v1 URL. Publish a new schema and endpoint instead.

### Run the checks locally

From the registry root, `go run ./cmd/registry-check -catalog-only` checks the schema, catalog alias, module directories, README links, and release pins. It needs Go and Git (including the release tags), but not Nix.

Run `go run ./cmd/registry-check` for the full CI check. It locks a temporary consumer, verifies that sibling inputs come from this checkout, validates each module with the SDK, and builds the Rust, archetype, and language suites. The default target is `x86_64-linux`; use `-system aarch64-darwin` to build on Apple Silicon. Nix reads Git-tracked files, so stage new module files before running. The checker does not modify this repository’s lockfiles.

### Coordinated SDK and registry changes

Ordinary PRs validate against `darkmatter/stackpanel` on `main`. If the registry needs an unpublished SDK change, run **Validate module catalog** on the registry branch with `sdk_revision` set to the full commit SHA of the SDK PR in `darkmatter/stackpanel`. If that SDK already consumes modules introduced by the registry PR, pass their space-separated input names in `sdk_module_inputs` (for example `fly javascript nextjs oxlint`). These inputs follow the checkout under test; other SDK dependencies keep their normal pins. To run the same check on `pull_request` before the dispatch workflow is available on `main`, maintainers can set repository variables `STACKPANEL_SDK_REVISION` and `STACKPANEL_SDK_MODULE_INPUTS` temporarily.

For local development, `go run ./cmd/registry-check -sdk-checkout ../stackpanel` uses a companion checkout without publishing an SDK revision. `SDK_MODULE_INPUTS` accepts the same space-separated slugs locally as `sdk_module_inputs` in the workflow.

Once the coordinated check passes, publish the module sources, lock the SDK's dogfood inputs to that published revision, and merge the SDK. Clear any temporary workflow variables and rerun against SDK `main` before publishing a numbered catalog release or embedding an updated snapshot.

## Using the Nix flake registry

Set `flake-registry = https://raw.githubusercontent.com/darkmatter/stackpanel-registry/main/registry.json` in `~/.config/nix/nix.conf`, or set `nix.settings.flake-registry` to that URL on NixOS/nix-darwin. For a single invocation:

```sh
nix --flake-registry https://raw.githubusercontent.com/darkmatter/stackpanel-registry/main/registry.json run stackpanel
```

To add a short name, append to `flakes[]` in `registry.json`, keeping entries alphabetized by `from.id`.
