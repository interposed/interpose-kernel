# interpose-kernel — roadmap

**Status:** Ubuntu-only single-flavor design (see [decisions/0001-ubuntu-only-kernel.md](decisions/0001-ubuntu-only-kernel.md)). v0.1 in progress.

## v0.1 — first published image

- [ ] `Dockerfile` written (multi-stage: fetch+verify+extract+repack)
- [ ] First successful `make build` produces an OCI image at `startaworldpeace/interpose-kernel:ubuntu-24.04-${KERNEL_VERSION}-bpf-lsm-v0.1.0`
- [ ] `scripts/validate.sh` passes against the image
- [ ] `scripts/extract-firecracker.sh` written + tested (extracts vmlinuz + builds rootfs.ext4 from modules tarball)
- [ ] Multi-arch (arm64 + amd64) under a single tag manifest
- [ ] First `make push` to Docker Hub
- [ ] Smoke test: image boots in Lima, `interpose serve --enforcer linux` loads BPF programs successfully

## v0.2 — production polish

- [ ] GitHub Actions: build on push to main, push on tag
- [ ] CVE-tracking automation: daily check of Ubuntu USN feed; auto-rebuild + manual-approval-gated push when relevant USN drops
- [ ] SBOM (CycloneDX) published alongside each tag
- [ ] Reproducibility: GitHub Actions reproduces locally-built image hash (no-secrets clean build)
- [ ] Signed images (cosign or notation)

## v0.3 — multi-version support

- [ ] Track multiple Ubuntu LTS releases simultaneously: 22.04, 24.04, future 26.04
- [ ] Tag scheme: `:ubuntu-${RELEASE}-${KERNEL_VERSION}-bpf-lsm-v${VERSION}` per Ubuntu release line
- [ ] Floating tags: `:ubuntu-${RELEASE}-bpf-lsm-latest` always points to the latest Canonical-released kernel for that LTS
- [ ] Compatibility notes in README: which interpose versions need which kernel features (BTF format, BPF helpers, etc.)

## v0.4 — sandbox-integration sugar

- [ ] `scripts/firecracker-vmconfig.sh` generates a ready-to-use Firecracker vmconfig.json that includes the right `boot_args` (`lsm=...,bpf`) automatically
- [ ] `scripts/lima-base.yaml` template — drop into `~/.lima/<vm-name>/lima.yaml` to use this kernel as the base
- [ ] Pre-baked variant: `:ubuntu-24.04-${KERNEL_VERSION}-bpf-lsm-with-interpose` that includes the interpose binary preloaded at `/usr/local/bin/interpose` (for sandboxes that don't want to install it themselves)

## v0.5 — observability + ops

- [ ] Image labels carry CVE-coverage metadata (`org.opencontainers.image.source`, `interposehq.kernel.cves-fixed-since=USN-XXXX`, etc.)
- [ ] `make verify` target: pulls our published image, validates it byte-for-byte against a fresh `make build`. Catches supply-chain attacks on Docker Hub.
- [ ] Per-CVE changelog at `docs/cve-log.md`

## v1.0 — official release

- [ ] Migration of Docker Hub namespace from `startaworldpeace/` to `interposehq/`
- [ ] First external production user
- [ ] Documented in interpose's main README as THE supported kernel image
- [ ] First "interpose-sandbox + interpose-kernel + interpose-sdk-go" end-to-end demo recorded

## Out of scope (deliberate)

- **Userspace base image.** This repo ships kernels. Userspace (interpose daemon + agent runtime) is `interpose-sandbox`'s job.
- **Non-Ubuntu base.** Per ADR-0001. Revisit only if Canonical's CVE pipeline becomes unreliable or a real customer ask demands it.
- **Custom kernel patches.** Stock Canonical bytes. No interpose-specific kernel mods.
- **Windows / macOS** kernels. Linux only. Mac users get Lima with this image; Windows users go through WSL2.
