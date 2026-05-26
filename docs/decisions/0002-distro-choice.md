# ADR 0002 — Why Ubuntu specifically (among the distros considered)

**Status:** Accepted, 2026-05-26. Supplements [ADR-0001](0001-ubuntu-only-kernel.md) (which establishes "we repackage a distro, not roll our own"). This ADR documents *which* distro and why.

## Context

ADR-0001 said: ship a distro kernel for the CVE-pipeline argument. This ADR answers: which distro?

Candidates considered: **Ubuntu, Debian, Alpine, Arch, Fedora, Rocky/CentOS**. Each was evaluated on six dimensions:

1. **BPF-LSM enabled in stock kernel?** (must-have)
2. **CVE response speed + structure** (the whole point of ADR-0001)
3. **LTS / stability cadence**
4. **Image weight** (kernel + minimal initramfs)
5. **Operator familiarity** (how often is this kernel actually deployed in production?)
6. **Build / repackaging pipeline complexity**

## Findings per candidate

### Ubuntu (24.04 LTS)

- **BPF-LSM**: ✅ enabled (verified via `apt source linux-image-virtual` config)
- **CVE pipeline**: ✅ Best-in-class. USN (Ubuntu Security Notices), 24-48h critical, weekly minor, ESM commitment, mailing-list subscription, machine-readable feeds
- **LTS**: 5-year mainstream support, +5 years ESM
- **Image weight**: ~150-250 MB (kernel + modules + initramfs)
- **Operator familiarity**: Extremely high — most popular dev/server distro, used by AWS/GCP/Azure as defaults
- **Build pipeline**: Trivial — `apt download linux-image-virtual` from `archive.ubuntu.com`, gpgv-verify, repack

**Score: dominant.** Strongest CVE pipeline + most familiar to operators.

### Debian (12 / Bookworm)

- **BPF-LSM**: ✅ enabled (Debian's kernel is upstream-aligned)
- **CVE pipeline**: ✅ Very strong. Debian Security Advisories (DSA), well-tracked, similar SLA to Ubuntu
- **LTS**: 5-year support via LTS team
- **Image weight**: Slightly smaller than Ubuntu (~120-200 MB)
- **Operator familiarity**: High — common server distro, defaults for many minimal Linux deployments
- **Build pipeline**: Same shape as Ubuntu (deb-based)

**Score: very close second.** The honest comparison vs Ubuntu is mostly "brand recognition" — Ubuntu USN is more universally subscribed-to than Debian DSA. We could ship Debian too with minor pipeline changes.

### Alpine Linux (3.21+ / linux-lts)

- **BPF-LSM**: ✅ likely enabled in `linux-lts` (Alpine has been adding BPF features since 2020; per [Alpine aports MR #33511](https://gitlab.alpinelinux.org/alpine/aports/-/merge_requests/33511) they actively maintain BPF tooling). Worth verifying via image inspection before committing.
- **CVE pipeline**: ⚠️ [Alpine security tracker](https://security.alpinelinux.org/) aggregates CVE data but Alpine [intentionally doesn't issue its own advisories](https://lists.alpinelinux.org/~alpine/devel/) — focus is on fixing rather than paperwork. Less structured than USN/DSA. Updates target <24h.
- **LTS**: 2-year support per release (shorter than Ubuntu's 5)
- **Image weight**: ✅ ~5-15 MB base image, ~50-100 MB total including kernel + minimal modules. Significantly lighter than Ubuntu.
- **Operator familiarity**: Medium — popular in container land (most Docker base images), less common as a kernel-runner
- **Build pipeline**: Slightly different (apk vs apt), but well-documented

**Score: strong on weight, weaker on advisory-pipeline structure.** Alpine's "fix don't paperwork" approach is operationally fine but means our automation has to scrape their `apkindex` rather than subscribe to a feed. If image weight becomes the deciding constraint, Alpine is the right answer; today, Ubuntu's structured pipeline wins.

### Arch Linux

- **BPF-LSM**: ✅ enabled (Arch's kernel is essentially mainline)
- **CVE pipeline**: ⚠️ [Arch Linux Security Advisories (ASA)](https://security.archlinux.org/) exist but rolling-release model means "fix" = "update to latest". No backporting to a stable point version.
- **LTS**: ❌ No LTS — rolling release. Operators get bleeding-edge but no stability guarantee.
- **Image weight**: Medium (~80-150 MB)
- **Operator familiarity**: Low for production (rolling release is rare in prod microVM scenarios)
- **Build pipeline**: Different (pacman/PKGBUILD), more effort to integrate

**Score: weak fit.** Rolling-release isn't what production agent sandboxes want — they want a stable kernel with selectively-backported security fixes, not "latest of everything." Disqualifies Arch for our use case despite the cleanliness of their kernel configs.

### Fedora

- **BPF-LSM**: ✅ enabled (Fedora is upstream-leading on BPF)
- **CVE pipeline**: ✅ Strong — Red Hat's CVE infrastructure feeds Fedora. Fast updates.
- **LTS**: ❌ 13-month support per release. Too short for production microVMs (operators don't want to migrate kernels every year).
- **Image weight**: Medium-large (~150-200 MB)
- **Operator familiarity**: Medium (Red Hat ecosystem; less common outside RHEL shops)
- **Build pipeline**: Different (dnf/rpm), more effort to integrate

**Score: short support window kills it.** Fedora's 13-month cycle is great for desktop but creates upgrade-treadmill problems for production microVMs.

### Rocky Linux / RHEL-compatible (9+)

- **BPF-LSM**: ✅ enabled (RHEL 9 kernel does)
- **CVE pipeline**: ✅ Excellent — Red Hat's enterprise-grade SLA, backports patches aggressively
- **LTS**: ✅ 10-year support
- **Image weight**: Large (~250-350 MB) — RHEL/Rocky kernels have lots of enterprise features built in
- **Operator familiarity**: Medium-high in enterprise (financial, defense, gov)
- **Build pipeline**: Different (dnf/rpm), more effort

**Score: legitimately strong second candidate for enterprise customers.** If a real customer demands "we run Rocky in prod, ship a Rocky-based interpose-kernel," this is the clear pick. But for v0.1, Ubuntu's broader familiarity wins.

## Decision

**Ubuntu 24.04 LTS, with `linux-image-virtual` kernel package, repackaged.**

Reasoning:
1. **Best CVE pipeline** for our use case: USN is the most-subscribed-to security feed in the world, structured machine-readable format, 24-48h critical SLA.
2. **Familiarity**: when an operator looks at `interpose-kernel:ubuntu-24.04-bpf-lsm-v0.1.0`, they immediately know what they're getting. No learning curve.
3. **LTS depth**: 10 years (5 mainstream + 5 ESM). Outlives most other choices.
4. **Trivial build pipeline**: pull deb + gpgv-verify + repack. ~10-15 min, easy to automate.

The runner-ups (Debian, Rocky, Alpine) are documented above. If a real customer demand surfaces for any of them, this ADR is superseded by a new ADR + a new flavor under `flavors/`.

## Future flavors (deferred, not closed)

The repo structure CAN accommodate multiple flavors if demand justifies it. Today it doesn't — single flavor (Ubuntu) keeps the maintenance burden low. Triggers for adding a flavor:

- **Add Alpine**: if image-weight at scale becomes a real constraint (50+ sandboxes/host). Alpine's tighter kernel + initramfs ~3x smaller.
- **Add Rocky**: first enterprise customer demand. Their security teams trust RHEL-derived more than community distros.
- **Add Debian**: if the Ubuntu USN feed ever degrades or Canonical changes their pricing/support model.

None of these are tracked v0.x work. They're documented here as known options.

## See also

- [ADR-0001](0001-ubuntu-only-kernel.md) — why distro repackage, not custom build
- [docs/STATUS.md](../STATUS.md) — current Ubuntu pipeline status
- [docs/cve-notification-system.md](../cve-notification-system.md) — how operators are notified when we repackage a new kernel
