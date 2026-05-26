# Ubuntu flavor — status

**As of 2026-05-26.** Designed, awaiting first build.

## Done
- `flavor.env` written with current Ubuntu 24.04 LTS kernel version + mirror + keyring
- README written
- Will use shared `Dockerfile.deb` (planned)

## Next (v0.1)
- [ ] First successful build via `build.sh ubuntu arm64`
- [ ] `scripts/validate.sh` passes (expect all green — Ubuntu's kernel has all flags)
- [ ] Smoke test in Lima (boot, run `interpose serve --enforcer linux`, observe BPF programs load)
- [ ] First push to `startaworldpeace/interpose-kernel:ubuntu-24.04-bpf-lsm-v0.1.0`
- [ ] Multi-arch (amd64 in addition to arm64)

## Verification baseline

When `validate.sh` runs against this flavor's built image, expect:
- `CONFIG_BPF=y` ✓
- `CONFIG_BPF_SYSCALL=y` ✓
- `CONFIG_BPF_JIT=y` ✓
- `CONFIG_BPF_LSM=y` ✓
- `CONFIG_DEBUG_INFO_BTF=y` ✓
- `CONFIG_DEBUG_INFO_BTF_MODULES=y` ✓
- `/sys/kernel/btf/vmlinux` populated at runtime (validated by booting)
- `CONFIG_LSM` does NOT include `bpf` by default (expected) — operator activates via `lsm=...,bpf` boot arg

If any required flag fails, file an issue + open a Canonical bug report; the flavor remains unshipped until upstream restores.

## Open questions

- Should we publish both `:ubuntu-24.04-bpf-lsm-v0.1.0` (immutable) and `:ubuntu-24.04-bpf-lsm-latest` (floating)? Probably yes — operators get to pin or float.
- When Ubuntu publishes a new kernel point release (every ~2 weeks per Canonical), do we auto-rebuild? Per `cve-notification-system.md`: yes via GitHub Actions cron + manual approval gate.
