## sandbox.d

Sandbox assets for tnk (Lima backend).

All sandboxes use Lima's `template:ubuntu` (Ubuntu 26.04 LTS with containerd/nerdctl).

- `manifests/` contains profile YAML manifests
- `provision.d/` contains provision scripts and shared library

Add custom profiles by placing a `*.sh` script in `provision.d/`. Optionally
add a matching `*.yaml` manifest in `manifests/` for resource overrides.
