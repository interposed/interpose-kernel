# interpose-kernel — Ubuntu flavor

Repackages Ubuntu 24.04 LTS's `linux-image-virtual` kernel deb as an OCI image with the interpose-kernel artifact layout (`/kernel`, `/kernel.tar`, `/kernel-dev.tar`, `/System.map`, `/interpose-kernel-info.json`).

**Image:** `startaworldpeace/interpose-kernel:ubuntu-24.04-bpf-lsm-<version>`

Built by `../../build.sh ubuntu ${ARCH}` which reads `flavor.env` and calls `../../Dockerfile.deb` (shared with Debian flavor — both are deb-based).

## What we get from Canonical

- ✅ `CONFIG_BPF_LSM=y` (verified)
- ✅ `CONFIG_DEBUG_INFO_BTF=y` + `_MODULES=y`
- ✅ Full LSM framework (`CONFIG_SECURITY=y`, securityfs)
- ✅ BPF stack (syscall, JIT)
- ⚠️ `bpf` NOT in default `CONFIG_LSM` chain — operator must activate via `lsm=...,bpf` boot arg (`interpose-sandbox` handles this; for Lima see existing grub override)

## Why pick this over Debian/Rocky

See [`../../docs/choosing-a-flavor.md`](../../docs/choosing-a-flavor.md). Short version:
- Most popular dev/server distro → most operator familiarity
- USN (Ubuntu Security Notices) is the most-subscribed security feed in Linux
- 10-year LTS support (5 mainstream + 5 ESM)

## Config

See [`flavor.env`](flavor.env) for the version we ship, mirror, signing key.

## Status

See [`STATUS.md`](STATUS.md).
