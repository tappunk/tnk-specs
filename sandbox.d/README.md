## sandbox.d

Sandbox assets for tnk (Lima backend).

All sandboxes use Lima's default `template:ubuntu` image, pinned to whichever
Ubuntu release the installed Lima version ships. Pin an exact release by
changing the template in `build_start_args` if a profile requires it.

- `manifests/base.yaml` — default resource limits for all profiles
- `provision.d/` — provision scripts and shared library in `lib/`

Add a custom profile by placing a `*.sh` script in `provision.d/`.
Optionally add a matching `<name>.yaml` in `manifests/` to override
`manifests/base.yaml` for that profile.
