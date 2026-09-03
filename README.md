<div align="center">
  <img src="https://raw.githubusercontent.com/tappunk/.github/refs/heads/main/assets/tnk-specs.webp" alt="tnk-specs" width="280"/>

# tnk-specs

Configuration and provisioning files for [tnk](https://github.com/tappunk/tnk).

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![X Follow](https://img.shields.io/twitter/follow/tappunk?style=social)](https://x.com/tappunk)

[Structure](#structure) · [Custom Specs](#custom-specs-repo) · [Full Docs](https://tappunk.com/tnk/)
</div>

---

## What's in this repo

- **Sandbox manifests** — per-profile definitions under `sandbox.d/manifests/`
- **Provision scripts** — setup automation under `sandbox.d/provision.d/`

`tnk init` deploys these into `~/.config/tnk/` on your host.

## Structure

```
tnk-specs/
├── tnk.toml                     # Config template installed into ~/.config/tnk/
├── sandbox.d/
│   ├── manifests/               # Sandbox manifests
│   └── provision.d/             # Provision scripts + shared lib/
└── LICENSE
```

## Custom specs repo

Point `tnk init` at a fork or custom specs repo:

```bash
tnk init --git-url https://github.com/custom/tnk-specs.git
```

## Full documentation

<https://tappunk.com/tnk/>
