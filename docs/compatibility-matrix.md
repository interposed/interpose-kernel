# Compatibility / feature matrix — three flavors

Side-by-side of Ubuntu, Debian, Rocky as interpose-kernel flavors. All expose **identical** interpose-side semantics — same LSM-BPF program loading, same hook invocations, same EPERM enforcement. Differences are about distro tooling, image footprint, support windows, and operator familiarity.

For the decision guide phrased as "what should I pick if I care about X," see [choosing-a-flavor.md](choosing-a-flavor.md).

## Core interpose support (must all be ✓ on every flavor)

| Capability | Ubuntu | Debian | Rocky |
|---|---|---|---|
| `CONFIG_BPF_LSM=y` | ✓ | ✓ | ✓ (RHEL 9 backport) |
| `CONFIG_DEBUG_INFO_BTF=y` | ✓ | ✓ | ✓ |
| `CONFIG_DEBUG_INFO_BTF_MODULES=y` | ✓ | ✓ | ✓ |
| `CONFIG_SECURITY=y` + securityfs | ✓ | ✓ | ✓ |
| BPF stack (syscall, JIT) | ✓ | ✓ | ✓ |
| `/sys/kernel/btf/vmlinux` populated | ✓ | ✓ | ✓ |
| `bpf` in default `CONFIG_LSM` chain | ✗ (boot arg) | ✗ (boot arg) | ✗ (boot arg) |

The last row is identical across all three — every distro ships `bpf` ENABLED in the kernel but NOT in the default active LSM list. Consumer activates via `lsm=...,bpf` cmdline. `interpose-sandbox` handles this for Firecracker; Lima/grub override for VM deployments.

## Versioning + support

| Aspect | Ubuntu | Debian | Rocky |
|---|---|---|---|
| Current LTS | 24.04 (Noble) | 12 (Bookworm) | 9 |
| Kernel version (as of 2026-05) | 6.8.x | 6.1.x | 5.14.x (heavily backported) |
| Mainstream support ends | 2029 | 2028 | 2032 |
| Extended/ESM ends | 2034 (10 yr) | 2028 (no ESM in our default) | 2032 (10 yr) |
| Kernel patch cadence | ~2 weeks per minor | ~4 weeks per minor | ~2 weeks per minor |
| Source-package URL pattern | `archive.ubuntu.com/.../linux-image-${V}-virtual_${X}_${ARCH}.deb` | `deb.debian.org/.../linux-image-${V}-cloud-${ARCH}_${X}_${ARCH}.deb` | `download.rockylinux.org/.../kernel-${V}.${ARCH}.rpm` |

## Image properties

| Metric | Ubuntu | Debian | Rocky |
|---|---|---|---|
| OCI image size | ~150-250 MB | ~120-200 MB | ~250-350 MB |
| Kernel binary (vmlinuz) | ~25 MB | ~25 MB | ~30 MB |
| Modules size | ~80-100 MB | ~60-80 MB | ~150-200 MB |
| Headers (kernel-dev.tar) | ~30-40 MB | ~30 MB | ~40-50 MB |
| Boot time (cold, Firecracker) | ~3-5 sec | ~2-4 sec | ~5-8 sec |
| Memory footprint per VM | ~100-200 MB | ~80-150 MB | ~150-250 MB |
| Driver coverage | full Ubuntu set | cloud-trimmed | full enterprise set |

Rocky carries the heaviest payload because RHEL kernels include drivers for the wide range of enterprise hardware (SAN, FC, RDMA, etc.) Debian's cloud variant is the lightest because it's specifically trimmed for VMs.

## Security pipeline

| Aspect | Ubuntu | Debian | Rocky |
|---|---|---|---|
| Advisory feed | USN (Ubuntu Security Notices) | DSA (Debian Security Advisories) | RHSA / RLSA (Red Hat / Rocky Linux Security Advisories) |
| Atom/RSS feed URL | https://ubuntu.com/security/notices.atom | https://www.debian.org/security/dsa.en.rdf | https://errata.rockylinux.org/api/v2/advisories |
| Machine-readable format | OVAL + JSON | DSA JSON + OVAL | JSON + CVRF |
| Critical CVE SLA | 24-48h | 24-48h | 24-48h (Red Hat enterprise SLA via Rocky) |
| Subscribed-to-ness | Highest (Canonical's brand) | High in Debian-shop circles | High in enterprise / compliance circles |

`docs/cve-notification-system.md` describes how interpose forwards these into operator notifications — same structure across all three flavors, just different upstream feeds.

## Build pipeline

| Aspect | Ubuntu | Debian | Rocky |
|---|---|---|---|
| Dockerfile | `Dockerfile.deb` (shared with Debian) | `Dockerfile.deb` (shared with Ubuntu) | `Dockerfile.rpm` |
| Extraction tool | `dpkg-deb -x` | `dpkg-deb -x` | `rpm2cpio | cpio -idm` |
| GPG verification | `gpgv` + `ubuntu-archive-keyring` | `gpgv` + `debian-archive-keyring` | `rpm --checksig` + Rocky's RPM-GPG-KEY-Rocky-9 |
| Builder base image | `debian:bookworm-slim` | `debian:bookworm-slim` | `rockylinux:9` |
| First-build time | ~10-15 min | ~10-15 min | ~15-25 min (rpm tooling is slightly slower) |

## When you DON'T pick by this matrix

If your team has a strong existing operational preference for one of the three (you already deploy that distro, your incident response runbooks assume it, your monitoring is set up for its logs) — pick that flavor regardless of any other consideration. The matrix is for cases where you don't already have a preference.

## What this matrix is NOT

- Not a security comparison. Three flavors, three CVE pipelines, three teams responding to CVEs. None is "more secure" — they're three independent operational pathways. Pick by which pathway you trust most, not by an imagined security delta.
- Not a performance comparison. Kernel performance differences across these three are negligible for interpose's workload. Image size and boot time are real but secondary to support-cycle and ops-fit considerations.
