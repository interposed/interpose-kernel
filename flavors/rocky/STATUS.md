# Rocky Linux flavor — status

**As of 2026-05-26.** Designed, awaiting first build. **Highest risk** of the three flavors due to RHEL kernel customization.

## Done
- `flavor.env` written for Rocky 9.4 + kernel-5.14.0-503.14.1.el9_5
- README written
- Uses `Dockerfile.rpm` (rpm-family; separate from deb-family Ubuntu/Debian)

## Next (v0.1)
- [ ] **First-priority verification**: download a Rocky 9 kernel rpm, extract the config, grep for `CONFIG_BPF_LSM`. RHEL kernels heavily customize — must confirm it's not disabled.
- [ ] Write `Dockerfile.rpm` (different from `Dockerfile.deb` — uses dnf/rpm tooling, separate GPG verification flow)
- [ ] First successful build via `build.sh rocky arm64`
- [ ] `scripts/validate.sh` passes
- [ ] Smoke test in a Rocky-equivalent VM (Vagrant-rockylinux or a Lima Rocky template)
- [ ] First push to `startaworldpeace/interpose-kernel:rocky-9-bpf-lsm-v0.1.0`

## Risks specific to this flavor

1. **RHEL kernel may disable BPF_LSM by default.** Red Hat sometimes disables newer kernel features in their stable kernels until they've audited them. If they did this for BPF_LSM in 9.4, we'd need to wait for them to enable it (next Rocky minor release) or use a non-stock kernel (which defeats the CVE pipeline argument). Verify FIRST before investing in the full Dockerfile.
2. **Larger image**: Rocky's kernel includes enterprise drivers (FC, iSCSI, RDMA, etc.) we don't need. Expect ~250-350 MB vs Ubuntu's ~150-250 MB. Acceptable.
3. **arm64 support quality**: Rocky's arm64 builds historically lag x86_64. Verify the kernel rpm for arm64 actually exists for the version we want.
4. **GPG key rotation**: Rocky rotated their archive key during the 9.x line. Pin to the current key fingerprint; refresh script needed for future rotations.

## Verification baseline

Same `validate.sh` checks as Ubuntu/Debian. The kernel version in `/kernel-source-info` will reflect Rocky's naming (`5.14.0-503.14.1.el9_5`).

## Open questions

- **Source provenance**: `dnf download --source kernel` gives us the source rpm URL. Should we embed that in `/interpose-kernel-info.json` as the provenance link, same shape as the Ubuntu deb URL? Yes.
- **RHSA → USN equivalence**: when we extend `cve-notification-system.md`'s update detection to Rocky, parse [RHSA advisories](https://access.redhat.com/security/security-updates/) (or use Rocky's own [RLSA](https://errata.rockylinux.org/) feed, which is more permissively accessible). The JSON payload's `cves_fixed_since_previous` shape is identical — just different upstream advisory IDs.
