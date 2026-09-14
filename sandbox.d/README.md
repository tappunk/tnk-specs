## sandbox.d

Sandbox assets for tnk (Lima backend).

All sandboxes use Lima's `template:ubuntu` (Ubuntu 26.04 LTS with containerd/nerdctl).

- `manifests/base.yaml` — default resource limits for all profiles
- `provision.d/` — provision scripts and shared library in `lib/`

Add a custom profile by placing a `*.sh` script in `provision.d/`.
Optionally add a matching `<name>.yaml` in `manifests/` to override
`manifests/base.yaml` for that profile.
