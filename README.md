<div align="center">
  <img src="https://raw.githubusercontent.com/tappunk/.github/refs/heads/main/assets/tnk-specs.webp" alt="tnk-specs" width="280"/>

# tnk-specs

Configuration and provisioning files for [tnk](https://github.com/tappunk/tnk).

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![X Follow](https://img.shields.io/twitter/follow/tappunk?style=social)](https://x.com/tappunk)

[Structure](#structure) · [Custom Specs](#custom-specs-repo) · [Full Docs](https://tappunk.com/tnk/)
</div>

---

## What's in this repo

- **Sandbox manifests** — per-profile definitions under `sandbox.d/manifests/`
- **Provision scripts** — setup automation under `sandbox.d/provision.d/`
- **Model presets** — engine model configuration files under `provider.d/`
- **Client templates** — reference configuration under `clients/`

`tnk init` deploys these into `~/.config/tnk/` on your host.

## Structure

``` 
tnk-specs/
├── sandbox.d/
│   ├── manifests/               # Sandbox manifests
│   └── provision.d/             # Provision scripts + shared lib/
├── provider.d/                  # Engine model presets
├── clients/                     # Reference config templates
└── LICENSE
```

## Custom specs repo

Point `tnk init` at a fork or custom specs repo:

```bash
tnk init --git-url https://github.com/custom/tnk-specs.git
```

## Full documentation

<https://tappunk.com/tnk/>
