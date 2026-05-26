# ADR 0001 — interpose-kernel ships Ubuntu's kernel, not our own

**Status:** Accepted, 2026-05-26.
**Authors:** founder team.
**Supersedes:** the multi-flavor design (linuxkit + ubuntu) briefly held earlier the same day.

## Context

interpose's LSM-BPF enforcer needs a Linux kernel with `CONFIG_BPF_LSM=y`, `CONFIG_DEBUG_INFO_BTF=y`, full LSM framework, and `bpf` in the active LSM chain at boot. No mainstream pre-built kernel image ships those — every project that needs them either compiles their own or repackages a distro kernel.

We needed to pick a build/distribute strategy for the `interpose-kernel` image consumed by `interpose-sandbox` (Firecracker microVM wrapper) and Lima dev setups.

## Options considered

### Option A — clean-room linuxkit-based build

Build a custom kernel from upstream Linux 6.6.71 source using linuxkit's `kernel/` build pipeline. Override the config to enable our flags. Publish as a small (~50-100 MB) OCI image with linuxkit's minimal init.

**Pros:**
- Smallest image (~50-100 MB), fastest boot (~1 sec), lowest RSS (~50 MB/VM)
- We control every byte in the kernel — minimal attack surface
- Strong reproducibility story (pin every input)

**Cons:**
- linuxkit's pinned alpine builder (alpine 3.21.3, pinned via image SHA) doesn't ship `pahole`, `libbpf-dev`, or `musl-obstack-dev` — three things required to build a BTF-enabled kernel. After 8 iterations of debugging:
  - Iter 1-3: strict diff check, EXTRA mechanism half-broken, python3 missing — all fixed
  - Iter 4-7: pahole not packaged; libbpf-dev not packaged; tried embedded libbpf submodule
  - Iter 8 (current wall): pahole source uses `obstack.h` (GNU/glibc only); musl doesn't have it; alpine doesn't have a `musl-obstack-dev` package
- Two reasonable unblocking paths (replace BUILD_IMAGE with Debian, or vendor our own kernel-build Dockerfile), each ~2-4 hours of focused work
- **CVE response is on us.** When a relevant Linux CVE drops, we'd need to rebuild + republish. Realistic cadence: days to weeks behind upstream.

### Option B — repackage Ubuntu's kernel as an OCI image

Pull `linux-image-virtual-${VER}` from Ubuntu's archive, GPG-verify, repackage with our artifact layout. The binary already has every compile-time flag we need.

**Pros:**
- The kernel binary is already correct — every `CONFIG_*` we need is set
- **Canonical's CVE pipeline is the security model.** 24-48h critical fix turnaround, weekly minor releases, USN announcements, decades of operational track record. A 4-person founder team cannot match this.
- Battle-tested kernel — millions of deployments, edge cases shaken out
- Operators familiar with Ubuntu's kernel logs, debug paths, module system
- Build pipeline is straightforward (multi-stage Docker, no alpine surgery)
- Larger image (~150-250 MB) — but not large in absolute terms

**Cons:**
- We don't control the kernel byte-for-byte. We accept whatever Canonical ships in that release.
- Bigger image, slower boot, higher per-VM RSS. Real at scale (10+ parallel sandboxes per host) but bearable.
- Driver bloat we don't need (every distro driver). Increases attack surface vs linuxkit option.
- Tied to Ubuntu's release cadence. If Canonical doesn't backport a kernel feature to the LTS we're on, we don't get it.

## Decision

**We ship Ubuntu's kernel.** Reason: Canonical's CVE pipeline is the single most important property for a security tool's kernel image. A multi-million-deployment, decade-stable security release pipeline beats anything a 4-person team can sustain.

The lightweight argument for linuxkit (3-5x smaller, faster boot) is real but secondary. For our use case — agent sandboxes that boot once per task and live for tens of minutes — sub-second boot time is a "nice to have," not a requirement. The CVE response delta is "we patch in 24h via Canonical" vs "we patch in days to weeks ourselves." That's the order-of-magnitude difference that decides it.

## Consequences

### Positive

- We inherit Canonical's security release pipeline at zero ongoing maintenance cost.
- Our build pipeline is short, robust, and reproducible per Ubuntu source-package version.
- Operators familiar with Ubuntu's kernel "feel at home" debugging interpose.
- The image artifact layout (`/kernel`, `/kernel.tar`, `/kernel-dev.tar`, `/kernel-source-info`) is consumer-stable — `interpose-sandbox`, Lima configs, etc. integrate against a single image format.

### Negative — accepted

- Image size is ~150-250 MB vs the ~50-100 MB a linuxkit-built one would be. Not a deal-breaker; pull-once-keep-cached works fine.
- Per-VM RSS is ~100-200 MB vs ~50 MB. At very high parallelism (say 50+ sandboxes/host), this matters; we accept it.
- We don't control the kernel config. If a flag we want isn't in Ubuntu's defaults, we're stuck. (Today the flags we need ARE in Ubuntu's defaults; this risk is hypothetical.)
- Activating `bpf` in the LSM chain still requires a boot-args change (Ubuntu's default `CONFIG_LSM` doesn't include bpf). `interpose-sandbox` sets this automatically via Firecracker's `boot_args`; Lima needs the existing grub override; documented in `docs/STATUS.md`.

### What we explicitly are NOT doing

- We are NOT shipping a custom-patched Ubuntu kernel. Stock Canonical bytes.
- We are NOT maintaining the linuxkit path in parallel. The 8-iteration debugging work is captured in this ADR (history below) as record-keeping; the active scaffold is deleted.
- We are NOT precluding a future linuxkit flavor if a real demand surfaces (e.g., a customer needs <100 MB image for extreme parallelism, OR Canonical's CVE pipeline becomes unreliable). If that day comes, this ADR is superseded with a new ADR explaining why.

## Linuxkit iteration history (archived)

For posterity, the path we walked before reaching this decision:

| Build # | What broke | Resolution |
|---|---|---|
| 1 | strict diff check at end of config merge | sed-patch the Dockerfile to skip when EXTRA isn't set |
| 2 | `make build-6.6.71` runs bcc tool build too; fails on cross-tag mismatch | invoke `linuxkit pkg build` directly |
| 3 | `env: can't execute 'python3'` in `tools/bpf/resolve_btfids` | add python3 to apk packages |
| 4 | `dwarves` package doesn't exist in alpine | try `pahole` |
| 5 | `pahole` package doesn't exist in alpine either | build pahole from source |
| 6 | pahole cmake needs libbpf>=0.4.0; libbpf-dev not in alpine | use embedded libbpf submodule |
| 7 | re-attempt libbpf-dev | switch to `--recurse-submodules` |
| 8 | pahole source uses `obstack.h` (GNU/glibc only); alpine ships `musl-obstack` runtime but not headers | **WALL** — would need Debian-based builder or vendored Dockerfile |

The 8 iterations weren't wasted — they produced the diagnostic (`interpose doctor --sandbox`, `scripts/sandbox-check.sh`) and concrete data confirming the problem space (no off-the-shelf kernel image has BPF-LSM). That work shipped in `interpose v0.8.4` and stands on its own.

## See also

- `docs/STATUS.md` — current build state
- `docs/roadmap.md` — what's next
- `interpose/docs/sandbox-environments.md` — diagnostic that proved this problem exists
- `interpose/docs/dev-lima.md` §3 — the existing grub override that's the boot-args precedent
