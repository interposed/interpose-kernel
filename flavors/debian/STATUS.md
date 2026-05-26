# Debian flavor — status

**As of 2026-05-26.** Designed, awaiting first build.

## Done
- `flavor.env` written for Debian 12 Bookworm + cloud kernel variant
- README written
- Shares `Dockerfile.deb` with Ubuntu flavor (deb-family)

## Next (v0.1)
- [ ] First successful build via `build.sh debian arm64`
- [ ] Verify `CONFIG_BPF_LSM=y` in Debian's stock cloud kernel (high confidence yes; needs confirmation)
- [ ] `scripts/validate.sh` passes
- [ ] Smoke test in a Debian-equivalent Lima VM (or a debian-cloud container)
- [ ] First push to `startaworldpeace/interpose-kernel:debian-12-bpf-lsm-v0.1.0`
- [ ] Multi-arch

## Verification expectation

Debian's cloud kernel is upstream-aligned; high confidence it has all the flags Ubuntu has. The notable potential gotcha is Debian's `cloud` variant uses a smaller config than `generic` — worth verifying BPF_LSM survived that trimming.

If it didn't, fall back to `linux-image-${VERSION}-${ARCH}` (the generic variant) — slightly heavier but functionally complete.

## Open questions

- **Cloud vs generic variant**: cloud is smaller (~100 MB vs ~150 MB) but config might differ. Default to cloud; fall back to generic if BPF_LSM missing.
- **`-amd64` vs `-cloud-amd64` naming**: Debian's package naming for cloud-variant kernel changed across releases. Verify against `apt show` for the current release.
