# interpose-kernel — current status

**As of 2026-05-26. v0.1.0 shipped.**

For where this repo fits in the broader interpose stack, see [where-this-fits.md](where-this-fits.md).

## v0.1.0 (current)

| Flavor | Build | Validate | Smoke test | Image | Size |
|---|---|---|---|---|---|
| Ubuntu 24.04 / 6.8.0-117-generic | ✅ | ✅ all 8 flags | ✅ QEMU/HVF boot + userspace-confirmed `bpf` in `/sys/kernel/security/lsm` from inside the VM | `startaworldpeace/interpose-kernel:ubuntu-24.04-bpf-lsm-v0.1.0` | 137 MB |
| Debian 12 / 6.1.0-48-cloud-arm64 | ✅ | ✅ all 8 flags; `bpf` in default LSM chain | — (not yet — same Dockerfile, expected to behave identically without `lsm=` boot arg) | `startaworldpeace/interpose-kernel:debian-12-bpf-lsm-v0.1.0` | 201 MB |
| Rocky 9                          | 🚧 | — | — | — | — |

Smoke-test evidence for Ubuntu (QEMU on macOS arm64 with HVF accel; Alpine 3.21 minirootfs as initrd; custom `/init` reads `/sys/kernel/security/lsm` then powers off):

```
uname: Linux 6.8.0-117-generic #117-Ubuntu SMP PREEMPT_DYNAMIC aarch64 Linux

active LSM chain (/sys/kernel/security/lsm):
lockdown,capability,landlock,yama,apparmor,bpf

/proc/filesystems has bpf?
nodev	bpf

kernel dmesg:
[    0.000081] LSM: initializing lsm=lockdown,capability,landlock,yama,apparmor,bpf,integrity
[    0.000103] LSM support for eBPF active
[    0.116681] reboot: Power down
```

`bpf` confirmed in the active LSM list from userspace inside the running VM — an LSM-BPF program can attach. Boot-to-shutdown took ~0.12 seconds (kernel dmesg timestamps).

## v0.2 themes

- **Rocky 9 build pipeline** — designed (ADR-0003), needs the `Dockerfile.rpm` path exercised end-to-end. RPM tooling has different ergonomics than `apt-get download`.
- **Multi-arch manifests** — currently arm64-only (built on Apple Silicon). Cross-build amd64 and publish a single multi-arch tag per flavor.
- **End-to-end smoke test with full rootfs** — boot each flavor under Firecracker with an Alpine rootfs, confirm a sample LSM-BPF program loads and enforces.
- **Push to Docker Hub** — images built locally; haven't been pushed. Hold until the multi-arch + Rocky work is done so the first published tag is the complete v0.2 set.
- **CVE notification metadata** — `/kernel-source-info` currently records flavor/version/arch/build-timestamp. Extend with USN/DSA/RHSA references so `interpose doctor` can flag operators when a CVE-patched rebuild is available. Design in [cve-notification-system.md](cve-notification-system.md).

## v0.3+

See [roadmap.md](roadmap.md).

## Open questions

1. **Pinning policy for kernel version** — do we follow latest LTS-stable continuously, or pin to a specific version per `interpose-kernel` major release? Currently latest-at-build-time; reconsider when we have multiple consumers.
2. **GPG verification depth** — `apt-get download` validates the package against the apt keyring of the builder image. For v0.2 we may want to additionally verify the Release/InRelease chain explicitly and pin the keyring fingerprint independent of the builder image.
3. **Update cadence for floating `:latest` tags** — automated daily check vs. release-on-CVE only. Lean toward release-on-CVE for now to keep operators in control of when their sandbox kernels rev.
