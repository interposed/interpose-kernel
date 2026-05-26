# interpose-kernel — Rocky Linux flavor

Repackages Rocky Linux 9's `kernel` rpm (a RHEL 9-compatible kernel with extensive Red Hat backports) as an OCI image with the interpose-kernel artifact layout.

**Image:** `startaworldpeace/interpose-kernel:rocky-9-bpf-lsm-<version>`

Built by `../../build.sh rocky ${ARCH}` which reads `flavor.env` and calls `../../Dockerfile.rpm` (rpm-based; separate Dockerfile from the deb-family Ubuntu+Debian).

## What we get from Rocky

- ✅ `CONFIG_BPF_LSM=y` — RHEL 9 enables it; needs verification on first build
- ✅ `CONFIG_DEBUG_INFO_BTF=y` — RHEL kernels enable BTF for bpftrace/perf
- ✅ Full LSM framework
- ⚠️ Like Ubuntu/Debian, `bpf` likely not in default `CONFIG_LSM` — activate via boot arg

## Why pick this over Ubuntu/Debian

See [`../../docs/choosing-a-flavor.md`](../../docs/choosing-a-flavor.md). Short version:
- **Enterprise compliance**: financial, defense, gov shops whose audit docs say "RHEL-compatible"
- **10-year support** per major release (longer than Ubuntu's mainstream LTS)
- **RHSA pipeline**: Red Hat's CVE infrastructure — enterprise-grade SLA, aggressive backporting
- Operator familiarity for RHEL/CentOS-shaped ops teams

## Config

See [`flavor.env`](flavor.env). Note: Rocky 9's GPG key is fetched from the mirror at build time; we verify its fingerprint matches the known `350D275CD5BAAD05` short-ID.

## Status

See [`STATUS.md`](STATUS.md). Rocky has more verification work than Ubuntu/Debian because:
- Kernel feature backports (RHEL 9's 5.14 kernel is heavily modified — need to confirm BPF_LSM survived)
- RPM extraction is different tooling than dpkg
- Image weight is largest of the three (~250-350 MB)
