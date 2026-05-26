# Where interpose-kernel fits

`interpose-kernel` is one layer of the broader interpose stack. This doc explains where it sits, why it has to exist, and when you actually need it.

## The stack

```
┌─────────────────────────────────────────────────────────────┐
│  User's AI agent (Claude Code, Cursor, custom agent, …)     │  ← the thing being gated
├─────────────────────────────────────────────────────────────┤
│  interpose-sandbox     (separate repo, not yet shipped)     │  ← Go wrapper around Firecracker
│  - spawns one microVM per agent                             │
│  - boots it from an interpose-kernel image                  │
│  - virtio-vsock bridge to host daemon                       │
├─────────────────────────────────────────────────────────────┤
│  interpose-kernel      (THIS REPO — v0.1.0)                 │  ← kernel files inside the VM
│  - Ubuntu 6.8 / Debian 6.1, both CONFIG_BPF_LSM=y           │
├─────────────────────────────────────────────────────────────┤
│  Firecracker           (off-the-shelf microVM hypervisor)   │  ← Amazon's KVM-based hypervisor
├─────────────────────────────────────────────────────────────┤
│  Linux host  (or macOS via Lima/HVF for dev)                │  ← interpose daemon lives here
└─────────────────────────────────────────────────────────────┘
```

This repo's deliverable is the **kernel layer** — `vmlinuz` + modules + headers + config, packaged as an OCI image so any sandbox runtime can pull and boot it.

## Why ship a custom kernel at all?

Firecracker boots from whatever `vmlinuz` you hand it. The default kernels everyone reaches for — Firecracker's own example kernel, Docker SBX's bundled kernel, off-the-shelf Alpine kernels — ship without `CONFIG_BPF_LSM=y`.

Without that one flag, the LSM-BPF programs that do interpose's enforcement **literally cannot load inside the VM**. The hook framework isn't compiled in; `bpf(BPF_PROG_LOAD, ..., BPF_PROG_TYPE_LSM)` returns `-EINVAL` and there's no software workaround.

So before any sandbox could exist, the kernel had to. That's what this repo is.

Once `CONFIG_BPF_LSM=y` is set, the same kernel still needs `bpf` in its active LSM chain. Two ways that gets activated:
- **Boot arg** (Ubuntu, Rocky): consumer passes `lsm=lockdown,capability,landlock,yama,apparmor,bpf` on the kernel command line. `interpose-sandbox` does this for Firecracker; Lima/grub does it for VM deployments.
- **Default chain** (Debian): Debian's stock 6.1 kernel already includes `bpf` in `CONFIG_LSM`. Boots LSM-active with zero boot args.

See [`compatibility-matrix.md`](compatibility-matrix.md) for the per-flavor breakdown.

## Two enforcement modes — only one needs this kernel

Interpose runs in two distinct modes. They share a broker, a passkey/YubiKey flow, and an audit log. They differ in **how the agent's actions are gated**.

### 1. Cooperative SDK (no kernel needed)

```
agent → interpose-sdk-go → interpose broker (host daemon) → YOUR passkey/yubikey
```

The agent (or its harness) imports `interpose-sdk-go` and voluntarily calls into the broker before sensitive actions. The agent must opt in — if it doesn't call the SDK, nothing gates it.

- **Pros:** runs anywhere (Mac, Linux, Windows); no VM, no kernel, no Firecracker; agent stays in its native environment
- **Cons:** trust-based — a buggy or malicious agent can simply skip the SDK call
- **Status:** shipping (`interpose-sdk-go v0.1.2`)
- **You DO NOT need this kernel** for cooperative mode.

### 2. Coerced sandbox (this kernel required)

```
agent (in microVM) → kernel syscall → LSM-BPF hook → interpose broker (via vsock) → YOUR passkey/yubikey
```

The agent runs inside a Firecracker microVM booted from one of this repo's kernel images. LSM-BPF programs inside the VM intercept syscalls and route them to the broker on the host. The agent doesn't need to cooperate — the kernel gates it regardless.

- **Pros:** works against any agent including unmodified third-party code; isolation breach is contained to the throwaway VM
- **Cons:** higher resource cost; agent runs in a Linux VM, so primarily a Linux-shaped workflow; needs `interpose-sandbox` (not yet shipped)
- **Status:** the kernel layer (this repo) shipped at v0.1.0; `interpose-sandbox` wrapper is the next repo
- **You DO need this kernel** for coerced mode.

## When you'd use this repo

- You're building `interpose-sandbox` or another Firecracker-based microVM sandbox and need a kernel with BPF-LSM compiled in.
- You're building any system that needs to load LSM-BPF programs inside a microVM (not just interpose — `bpftrace`-style use cases, custom kernel security work).
- You want a kernel image with verifiable upstream provenance (one of Ubuntu/Debian/Rocky's signed packages, repackaged with the build trail in `/kernel-source-info`).

## When you would NOT use this repo

- You only need the cooperative SDK mode → integrate `interpose-sdk-go` directly, no VM required.
- You're running interpose-daemon on the host kernel itself (not in a VM) → use whatever kernel your distro ships; the host kernel either already has `CONFIG_BPF_LSM=y` (most modern distros do) or it doesn't (you'd need to enable it the same way distros do — by rebuilding their kernel package).
- You're on macOS-only (no Linux VM in the picture) → ES-based enforcement, separate code path entirely.

## Validation evidence

The Ubuntu flavor was smoke-tested under QEMU with HVF acceleration (macOS arm64). Boot output confirms BPF-LSM is alive end-to-end:

```
Linux version 6.8.0-117-generic … #117-Ubuntu SMP PREEMPT_DYNAMIC
Kernel command line: console=ttyAMA0 panic=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf
LSM: initializing lsm=lockdown,capability,landlock,yama,apparmor,bpf,integrity
landlock: Up and running.
LSM support for eBPF active
```

`LSM support for eBPF active` is the kernel's own confirmation that `CONFIG_BPF_LSM=y` is compiled in and registered. `bpf` in the active LSM list confirms the boot-arg activation path works.

Debian flavor needs no boot arg (bpf is in its default chain) — same evidence will appear in its boot log without `lsm=` on the cmdline.
