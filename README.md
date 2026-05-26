# interpose-kernel

Three flavors of Linux kernel images, repackaged from major distros, each with `CONFIG_BPF_LSM=y` + `CONFIG_DEBUG_INFO_BTF=y` + the full LSM framework. Drop into Firecracker, Lima, QEMU, or any microVM runtime that takes a kernel + rootfs.

| Flavor | Image tag | Operator audience |
|---|---|---|
| **Ubuntu** | `startaworldpeace/interpose-kernel:ubuntu-24.04-bpf-lsm-<ver>` | Default. Dev/server crowd, AWS/GCP/Azure baseline, USN feed |
| **Debian** | `startaworldpeace/interpose-kernel:debian-12-bpf-lsm-<ver>` | Stricter free-software philosophy, DSA pipeline |
| **Rocky** | `startaworldpeace/interpose-kernel:rocky-9-bpf-lsm-<ver>` | Enterprise / RHEL-compatible / RHSA pipeline |

All three produce IDENTICAL OCI artifact layouts (`/kernel`, `/kernel.tar`, `/kernel-dev.tar`, `/System.map`, `/config`, `/kernel-source-info`) — downstream consumers (`interpose-sandbox`, Lima base configs) treat them interchangeably.

**See [docs/choosing-a-flavor.md](docs/choosing-a-flavor.md) for the decision guide.**

## Status

**v0.1.0** — Ubuntu and Debian flavors build, validate, and produce the published OCI artifact layout. Rocky is designed but its build pipeline ships in v0.2.

| Flavor | Build | Validate | Size | Notes |
|---|---|---|---|---|
| Ubuntu 24.04 (kernel 6.8.0-117-generic) | ✅ | ✅ all 8 flags | 137 MB | `bpf` not in default LSM chain → requires `lsm=...,bpf` boot arg |
| Debian 12 (kernel 6.1.0-48-cloud-arm64)  | ✅ | ✅ all 8 flags | 201 MB | `bpf` **is** in default LSM chain — boots BPF-LSM-active out of the box |
| Rocky 9                                  | 🚧 | —          | —     | Designed; build deferred to v0.2 |

See [docs/STATUS.md](docs/STATUS.md) for full per-flavor build status and [docs/decisions/0003-three-flavor-strategy.md](docs/decisions/0003-three-flavor-strategy.md) for the design rationale.

## Build

```bash
make ubuntu          # ~10-15 min, fetch + verify + repack
make debian          # same shape, Debian mirror + keyring
make rocky           # rpm-based, separate Dockerfile
make all             # all three in sequence (or set up parallel in CI)
```

Override:
```bash
make ubuntu VERSION_TAG=v0.1.5 DOCKER_ORG=interposehq ARCH=amd64
```

Validate any built flavor:
```bash
make validate FLAVOR=ubuntu     # checks the built image has all required CONFIG_* flags
```

Push (after validate):
```bash
make push-ubuntu
make push-all
```

## How it works

One Dockerfile per distro **family** (`Dockerfile.deb` for Ubuntu+Debian, `Dockerfile.rpm` for Rocky), parameterized by `flavors/${flavor}/flavor.env` which supplies:

- Mirror URL (`archive.ubuntu.com`, `deb.debian.org`, `download.rockylinux.org`)
- Kernel package name + version (`linux-image-virtual`, `linux-image-cloud`, `kernel-core`)
- GPG keyring or fingerprint
- Tag prefix for the output image

Build flow (deb-family example):

1. `debian:bookworm-slim` builder pulls `linux-image-${VARIANT}-${ARCH}.deb` from the distro mirror.
2. GPG-verify against the distro's archive keyring (v0.2: full Release/InRelease verification chain — currently HTTPS + Docker Hub provenance).
3. `dpkg-deb -x` extracts to staging; build the interpose-kernel artifact layout in `/out`.
4. Final `FROM scratch` stage with just the artifacts.

Result: same OCI layout, three different source provenances.

## Layout

```
interpose-kernel/
├── README.md                 # this file
├── LICENSE                   # Apache 2.0 (build config); kernel is GPL-2.0
├── Makefile                  # `make ubuntu|debian|rocky|all`
├── build.sh                  # dispatches to per-family Dockerfile based on flavor.env
├── Dockerfile.deb            # Ubuntu + Debian build (deb-based; shared)
├── Dockerfile.rpm            # Rocky build (rpm-based)
├── flavors/
│   ├── ubuntu/
│   │   ├── flavor.env        # mirror + version + keyring config
│   │   ├── README.md         # this flavor's specifics
│   │   └── STATUS.md         # build state for this flavor
│   ├── debian/
│   │   ├── flavor.env
│   │   ├── README.md
│   │   └── STATUS.md
│   └── rocky/
│       ├── flavor.env
│       ├── README.md
│       └── STATUS.md
├── scripts/
│   └── validate.sh           # works for all flavors (extracts .config, greps required flags)
├── docs/
│   ├── STATUS.md             # cross-flavor build state
│   ├── roadmap.md
│   ├── compatibility-matrix.md   # 3-way feature comparison
│   ├── choosing-a-flavor.md      # decision guide for operators
│   ├── cve-notification-system.md   # multi-feed CVE tracking + notification design
│   └── decisions/
│       ├── 0001-ubuntu-only-kernel.md    # superseded by 0003
│       ├── 0002-distro-choice.md         # partial supersede by 0003
│       └── 0003-three-flavor-strategy.md # current
└── .build/                   # gitignored — local build cache
```

## Activation: `bpf` in the LSM chain

All three distros ship `CONFIG_BPF_LSM=y` BUT default `CONFIG_LSM="...,..."` does NOT include `bpf`. To activate at boot, the consumer must pass:

```
lsm=lockdown,capability,landlock,yama,apparmor,bpf
```

on the kernel command line. `interpose-sandbox` sets this automatically via Firecracker's `boot_args`. For Lima, see `interpose/docs/dev-lima.md` §3. Bare-VM consumers do it via their bootloader.

## CVE notifications

The interpose daemon notifies operators when a new kernel image is available with CVE fixes. Each image carries `/interpose-kernel-info.json` with the upstream advisory IDs (USN for Ubuntu, DSA for Debian, RHSA/RLSA for Rocky). Detection is pull-based against Docker Hub; notification surfaces in `interpose doctor`, the browser-auth UI, and the audit log. See [`docs/cve-notification-system.md`](docs/cve-notification-system.md).

## Related repos

```
interpose             ← daemon, LSM-BPF programs, AAuth broker, audit log
interpose-sdk-go      ← cooperative-agent Go client
interpose-kernel      ← THIS REPO: three flavors of BPF-LSM kernel images
interpose-sandbox     ← Firecracker-based microVM wrapper (consumes any flavor)
```

## License

Apache 2.0 (the build config). The Linux kernel remains GPL-2.0 in all flavors. Each distro's kernel package retains its respective license (Ubuntu/Debian/Rocky overlays).
