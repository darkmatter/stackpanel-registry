"""Inspect a dockerTools archive without extracting paths or following host symlinks."""
import hashlib
import json
import posixpath
import sys
import tarfile

archive, expected = sys.argv[1:]
links = {}
embedded = None
with tarfile.open(archive) as image:
    manifest, = json.load(image.extractfile("manifest.json"))
    config = json.load(image.extractfile(manifest["Config"]))
    assert (config["os"], config["architecture"], config["config"]["Cmd"]) == (
        "linux", "amd64", ["/app/server"]
    ), config
    for name in manifest["Layers"]:
        with tarfile.open(fileobj=image.extractfile(name), mode="r|*") as layer:
            for member in layer:
                path = posixpath.normpath("/" + member.name)
                if member.issym():
                    links[path] = posixpath.normpath(posixpath.join(posixpath.dirname(path), member.linkname))
                if path == expected and member.isfile():
                    assert member.mode & 0o111, f"{path} is not executable"
                    embedded = hashlib.file_digest(layer.extractfile(member), "sha256").digest()

# Follow links inside the archive only: dockerTools may route /app/server
# through its intermediate container-root package.
server = links.get("/app", "/app") + "/server"
seen = set()
while server in links:
    assert server not in seen, f"cyclic link at {server}"
    seen.add(server)
    server = links[server]
assert server == expected, f"/app/server resolves to {server}, not {expected}"
with open(expected, "rb") as binary:
    assert embedded == hashlib.file_digest(binary, "sha256").digest(), f"wrong or missing {expected}"
