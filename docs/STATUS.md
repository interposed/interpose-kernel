# interpose-kernel — current status

**As of 2026-05-26. v0.1 in progress.**

## Done

- ✅ Architecture decision: Ubuntu kernel repackaging, not custom linuxkit build. See [decisions/0001-ubuntu-only-kernel.md](decisions/0001-ubuntu-only-kernel.md).
- ✅ Repo restructure: single-flavor, clean layout
- ✅ README + roadmap + this STATUS doc
- ✅ `scripts/validate.sh` (works for any kernel image with our artifact layout)
- ✅ `Makefile` targets defined: `build`, `validate`, `push`
- ✅ `build.sh` skeleton (Dockerfile call wrapper; Dockerfile itself TODO)

## In progress / next

- [ ] Write `Dockerfile`
  - Multi-stage: fetch + verify + extract + repackage
  - Stage 1 (`debian:bookworm-slim`): install `gnupg`, `curl`, `ubuntu-archive-keyring`. Download `linux-image-virtual-${UBUNTU_RELEASE}-${ARCH}.deb` + `linux-headers-virtual-${UBUNTU_RELEASE}-${ARCH}.deb` from `archive.ubuntu.com`. Verify with `gpgv`. Verify sha256 from `Packages.gz`.
  - Stage 2 (`scratch`): extract deb contents to the linuxkit-compatible artifact layout (`/kernel`, `/kernel.tar`, `/kernel-dev.tar`, `/System.map`, `/kernel-source-info`).
- [ ] Pin specific Ubuntu source-package version for reproducibility
- [ ] Run `scripts/validate.sh` against the built image
- [ ] Smoke test boot in Lima / Firecracker

## v0.1 deliverable

A pushed image at `startaworldpeace/interpose-kernel:ubuntu-24.04-${KERNEL_VERSION}-bpf-lsm-v0.1.0` with:
- vmlinuz that boots
- modules tarball that loads
- headers + .config that pass validate.sh
- source provenance recorded

## v0.2+

See [roadmap.md](roadmap.md).

## Open questions

1. **Where to keep the Ubuntu archive GPG key?** Embed in repo (reproducible but needs rotation tracking) or fetch at build time (always current but build is not offline). Recommend: embed, with a refresh script.
2. **Multi-arch in one image manifest?** Recommend yes — one tag for the operator, two underlying images (`linux/amd64` + `linux/arm64`).
3. **Update cadence for `:latest`?** GitHub Actions daily cron checks Ubuntu archive for new kernel debs. Manual approval gate before push for the first few rounds; automate fully after we trust the pipeline.
