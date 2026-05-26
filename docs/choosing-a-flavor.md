# Choosing a flavor

interpose-kernel ships three flavors — Ubuntu, Debian, Rocky. All expose identical interpose-side capabilities (BPF-LSM + BTF + securityfs). Pick by operational fit.

See [compatibility-matrix.md](compatibility-matrix.md) for the side-by-side.

## TL;DR

| Your situation | Pick |
|---|---|
| "I don't have a strong opinion." | **Ubuntu** (the default; most operator familiarity) |
| "We deploy on Ubuntu in prod." | **Ubuntu** |
| "We deploy on Debian / prefer Debian's philosophy." | **Debian** |
| "We deploy on RHEL/Rocky/AlmaLinux in prod." | **Rocky** |
| "Our compliance docs say RHEL-compatible." | **Rocky** |
| "We need 10-year support." | **Rocky** (RHEL's 10-year cycle) |
| "We need lighter image; don't care about distro brand." | **Debian** (cloud variant slightly smaller than Ubuntu) |
| "We're evaluating against Docker SBX." | **Ubuntu** (closest brand parity) |
| "Customer eval — they'll dig in." | Match what they already deploy. Default Ubuntu if unknown. |
| "Bleeding-edge kernel needed (BPF feature in 6.10+)." | **Ubuntu** (latest LTS kernel of the three) |

## Long form

### What all three give you

Same interpose enforcer behavior. Same `interpose serve --enforcer linux` outcomes. Same audit log. Same SDK API. **The flavor choice is purely about the kernel image — not about how interpose itself behaves.**

### Ubuntu

**Pick this if:** You don't have a strong reason to pick another. It's the default.

**Strengths:**
- Most operators have run an Ubuntu kernel. Familiar logs, familiar /proc paths, familiar package management.
- USN (Ubuntu Security Notices) is the most widely-subscribed security feed in Linux. Your existing CVE infrastructure probably already consumes it.
- 5-year mainstream + 5-year ESM support per LTS.
- Largest community → fastest answers when something goes weird.

**Weaknesses:**
- Carries Canonical-specific kernel features you might not use (snap-related, livepatch hooks, etc.). Marginal bloat.
- Larger than Debian's cloud variant by ~30-50 MB.

### Debian

**Pick this if:** You already deploy on Debian, OR you specifically want a kernel free of Canonical-specific overlays.

**Strengths:**
- Stricter free-software-only philosophy. Debian's kernel team rejects firmware blobs and proprietary modules in `main`.
- DSA pipeline is well-tested over decades. Conservative release engineering.
- Slightly smaller image (~120-200 MB vs Ubuntu's ~150-250 MB) when using the `cloud` variant.
- 5-year LTS support via the Debian LTS team.

**Weaknesses:**
- Slightly older kernel point versions than Ubuntu at any given time (Debian conservative; Ubuntu more aggressive on point-release bumps).
- Smaller community than Ubuntu → slightly slower answers for rare issues.
- The `cloud` variant trims some configs that might matter; verify BPF-LSM survived (high confidence yes).

### Rocky Linux 9

**Pick this if:** You deploy on RHEL or RHEL-compatible (CentOS Stream, AlmaLinux, Oracle Linux) in production, OR your compliance docs require RHEL-derived.

**Strengths:**
- Red Hat's RHSA pipeline is enterprise-grade — fastest backport schedule, longest support window (10-year per major).
- RHEL kernels include extensive backports of upstream features into older kernels (5.14 base + years of backports). Stability over novelty.
- Operator familiarity for RHEL/CentOS shops (enterprise, fintech, defense, gov).
- Rocky/AlmaLinux are exact RHEL rebuilds, so kernel behavior matches RHEL production exactly.

**Weaknesses:**
- Largest image (~250-350 MB) — RHEL kernels carry every driver enterprise customers might need.
- arm64 build cadence sometimes lags x86_64. Verify your target arch's specific release is available.
- Older base kernel version (5.14) than Ubuntu/Debian — backports give you most modern features but not all bleeding-edge BPF capabilities.

## Multi-flavor in one deployment

Different sandboxes on the same host can use different flavors. `interpose-sandbox` (planned v0.x) accepts `--kernel-flavor=ubuntu|debian|rocky` per-sandbox, so you can:

- Run a dev sandbox on Ubuntu (familiar logs for debugging),
- Run a compliance-relevant sandbox on Rocky (audit story matches),
- All managed by the same `interpose-sandbox ls`.

## Switching flavors

You can change per-sandbox at boot time. The interpose policy / audit log / SDK API are flavor-agnostic. The only visible diff is the kernel logs.

## Not on the menu

Per [ADR-0002](decisions/0002-distro-choice.md), we considered and ruled out: Alpine (advisory pipeline not structured enough), Arch (rolling release wrong for production microVMs), Fedora (13-month support cycle creates upgrade-treadmill).

If your situation demands one of these, file an issue with the case. Adding a fourth flavor is mechanical given the parameterized pipeline; we need the operator-demand signal.
