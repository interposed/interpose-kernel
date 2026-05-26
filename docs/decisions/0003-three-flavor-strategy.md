# ADR 0003 — Ship three distro flavors (Ubuntu, Debian, Rocky), unified pipeline

**Status:** Accepted, 2026-05-26. **Supersedes** [ADR-0001](0001-ubuntu-only-kernel.md) (kept for history but its "single flavor" conclusion is replaced) and [ADR-0002](0002-distro-choice.md) (its analysis of alternatives stands; the "Ubuntu only" verdict is replaced).

## Context

ADR-0001 + ADR-0002 reached "Ubuntu only" because we wanted to keep maintenance burden low while we validated the design. Three hours later we re-evaluated and concluded:

- All three (Ubuntu, Debian, Rocky/RHEL 9) follow the same repackaging pattern. The pipeline can be parameterized over distro config — one Dockerfile, three thin flavor configs.
- Each serves a meaningfully different operator audience that's hard to convert later. Adding flavors retroactively risks "we picked Ubuntu, all our docs/examples/integrations assume it" lock-in.
- The CVE notification system from [`docs/cve-notification-system.md`](../cve-notification-system.md) already supports multiple upstream feeds (USN, DSA, RHSA). The architecture wants multi-flavor.

## Decision

**Ship three flavors in parallel from a unified pipeline:**

- **`ubuntu-${RELEASE}-bpf-lsm-${VERSION}`** — Ubuntu 24.04 LTS, repackaged
- **`debian-${RELEASE}-bpf-lsm-${VERSION}`** — Debian 12 Bookworm, repackaged
- **`rocky-${RELEASE}-bpf-lsm-${VERSION}`** — Rocky Linux 9, repackaged

All three:
- Produce identical OCI artifact layouts (`/kernel`, `/kernel.tar`, `/kernel-dev.tar`, `/System.map`, `/interpose-kernel-info.json`).
- Pass the same `scripts/validate.sh`.
- Are produced by the same Dockerfile (parameterized via build args from `flavors/${FLAVOR}/flavor.env`).
- Feed into the same CVE notification system, each forwarding their distro's advisory format.

A single repo, single Dockerfile, three flavor configs.

## Why each flavor

### Ubuntu 24.04 LTS

- **Audience:** the default. Dev/server crowd, AWS/GCP/Azure baseline, USN feed the most-subscribed-to security stream in the world.
- **Strength:** best operator familiarity + strongest advisory pipeline structure.
- **Image:** ~150-250 MB.

### Debian 12 Bookworm

- **Audience:** ops teams that prefer Debian's stricter free-software-only philosophy, or that already run Debian as their base server distro. Some prefer Debian over Ubuntu specifically because they don't want Canonical's snap/ad-related changes in their kernel.
- **Strength:** Debian Security Advisories (DSA) — very strong, similar SLA to USN. Slightly smaller image than Ubuntu (less Canonical-specific kernel features). LTS team supports 5 years.
- **Image:** ~120-200 MB.

### Rocky Linux 9

- **Audience:** enterprise (financial, defense, government, anyone whose compliance docs say "RHEL-compatible"). Operators whose existing observability and incident response is RHEL-shaped.
- **Strength:** Red Hat's RHSA pipeline — enterprise-grade SLA, 10-year support, aggressive backporting. Kernel feature set tuned for production workloads.
- **Image:** ~250-350 MB (heavier; enterprise distros include more drivers).

Together: covers consumer dev (Ubuntu), philosophy/Debian-fan ops (Debian), and enterprise compliance (Rocky). Three real audiences, minimal additional code.

## Why unified pipeline

The danger of multi-flavor is N×N maintenance: three pipelines, three sets of bugs, three places to update when something changes. We avoid that by making the differences DATA, not CODE.

```
flavors/
├── ubuntu/
│   ├── flavor.env         # PACKAGE_URL, GPG_KEY_URL, KERNEL_VARIANT, etc.
│   ├── STATUS.md
│   └── README.md
├── debian/
│   ├── flavor.env
│   ├── STATUS.md
│   └── README.md
└── rocky/
    ├── flavor.env
    ├── STATUS.md
    └── README.md
```

The Dockerfile (one) reads build args from the `flavor.env` for whichever flavor `build.sh` is invoking. Operators run:

```bash
make ubuntu    # → reads flavors/ubuntu/flavor.env, builds the Ubuntu image
make debian    # → same Dockerfile, different env
make rocky     # → same Dockerfile, different env
make all       # → builds all three
```

Adding a fourth flavor (say, Alpine if it ever ranks high enough) would be a single new directory under `flavors/`.

## What this changes vs. ADR-0002

ADR-0002 documented Debian and Rocky as known options with explicit triggers for "we'd add this as a second flavor if X happens." The triggers haven't fired (no specific customer ask), but:

- **Reframing**: instead of "wait for ask", we ship the option proactively. The cost is minimal once we've built the parameterized pipeline; the value is operators see a real choice from day 1.
- **Lock-in concern**: if interpose-sandbox, demo videos, marketing, and docs all assume Ubuntu, switching costs grow. Shipping three from the start avoids that.
- **Honest comparison**: we get to test the operator-choice UX (compatibility matrix, choose-a-flavor doc) against three real options, not one + two theoretical.

ADR-0002's research stands — Alpine/Arch/Fedora are still NOT recommended for the reasons documented there.

## What still rules out 4+ flavors

Per ADR-0002:
- **Alpine**: image weight is its only edge. If we add it, that's the trigger.
- **Arch**: rolling release fundamentally incompatible with our stable-microVM use case. Not adding.
- **Fedora**: 13-month support cycle creates upgrade-treadmill. Not adding.

Adding any of these is a future ADR. The three picked here cover ~90% of production Linux ops in 2026.

## Consequences

### Positive

- Real operator choice from day one of a public release.
- One Dockerfile, three flavors → low marginal maintenance per flavor.
- Compatibility matrix becomes a real-world artifact, not theoretical.
- CVE-notification design (`cve-notification-system.md`) is exercised against three different upstream feed formats, surfacing edge cases earlier.

### Negative — accepted

- Build time roughly 3x (three flavors instead of one). Mitigated: parallel builds in CI.
- Three images to maintain CVE coverage for. Mitigated: each follows its distro's advisory pipeline (we don't do CVE research ourselves; we forward).
- Decision paralysis risk for new operators ("which do I pick?"). Mitigated: docs/choosing-a-flavor.md is opinionated — Ubuntu is the default unless you have reason.
- Three places where a kernel-config wishlist might not land (we don't control any of them). Mitigated: validate.sh catches missing flags immediately.

## See also

- [ADR-0001](0001-ubuntu-only-kernel.md) — *superseded*; reason: see this ADR
- [ADR-0002](0002-distro-choice.md) — *partially superseded*; the distro analysis stands, the "Ubuntu only" verdict is replaced
- [`docs/cve-notification-system.md`](../cve-notification-system.md) — extends naturally to three feeds (USN + DSA + RHSA)
- [`docs/compatibility-matrix.md`](../compatibility-matrix.md) — three-way feature comparison (to be added)
- [`docs/choosing-a-flavor.md`](../choosing-a-flavor.md) — decision guide (to be added)
