# interpose-kernel — Debian flavor

Repackages Debian 12 Bookworm's `linux-image-cloud` (or `-amd64`/`-arm64`) kernel deb as an OCI image with the interpose-kernel artifact layout.

**Image:** `startaworldpeace/interpose-kernel:debian-12-bpf-lsm-<version>`

Built by `../../build.sh debian ${ARCH}` which reads `flavor.env` and calls `../../Dockerfile.deb` (shared with Ubuntu — both deb-based; the difference is mirror + keyring + version).

## What we get from Debian

- ✅ `CONFIG_BPF_LSM=y` (Debian's kernel tracks upstream closely)
- ✅ `CONFIG_DEBUG_INFO_BTF=y`
- ✅ Full LSM framework
- ⚠️ Like Ubuntu, `bpf` not in default `CONFIG_LSM` — activate via boot arg

## Why pick this over Ubuntu/Rocky

See [`../../docs/choosing-a-flavor.md`](../../docs/choosing-a-flavor.md). Short version:
- Stricter free-software philosophy than Ubuntu (no snap, no Canonical-specific kernel features)
- Slightly smaller image (~120-200 MB vs Ubuntu's ~150-250 MB) — Debian's cloud kernel omits some Canonical-only features
- Debian Security Advisories (DSA) — strong feed, similar SLA to USN, 5-year LTS support

## Config

See [`flavor.env`](flavor.env).

## Status

See [`STATUS.md`](STATUS.md).
