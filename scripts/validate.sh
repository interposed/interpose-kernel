#!/usr/bin/env bash
# validate.sh — confirm a built interpose-kernel image actually has BPF-LSM,
# BTF, and the right LSM chain. Reads the kernel's .config out of the
# kernel-dev.tar artifact embedded in the image.

set -euo pipefail

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
	DOCKER_ORG="${DOCKER_ORG:-startaworldpeace}"
	IMAGE_NAME="${IMAGE_NAME:-interpose-kernel}"
	IMAGE=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${DOCKER_ORG}/${IMAGE_NAME}:" | head -1)
	if [ -z "$IMAGE" ]; then
		echo "usage: $0 <image:tag>" >&2
		echo "   (or set DOCKER_ORG + IMAGE_NAME env to auto-detect)" >&2
		exit 64
	fi
fi

echo "==> validating $IMAGE"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cd "$TMPDIR"
docker save "$IMAGE" -o image.tar
mkdir layers && tar xf image.tar -C layers
mkdir rootfs
for layer in layers/blobs/sha256/*; do
	tar -tf "$layer" 2>/dev/null | head -1 >/dev/null && \
		tar xf "$layer" -C rootfs 2>/dev/null
done

# Find the kernel config. Two layouts:
#   1) Top-level /config artifact (deb-based flavors).
#      Ubuntu's linux-modules ships /boot/config-${VER}-${VARIANT};
#      our build copies it to the image root as /config.
#   2) Inside kernel-dev.tar at usr/src/.../.config (linuxkit-style).
CFG=""
if [ -f rootfs/config ]; then
	CFG="rootfs/config"
	echo "==> using top-level /config artifact"
else
	DEV_TAR="$(find rootfs -name 'kernel-dev.tar' | head -1)"
	if [ -n "$DEV_TAR" ]; then
		tar -xf "$DEV_TAR" --wildcards '*/.config' 2>/dev/null || true
		CFG=$(find . -name '.config' -path '*linux-headers*/.config' 2>/dev/null | head -1)
	fi
fi

if [ -z "$CFG" ] || [ ! -f "$CFG" ]; then
	echo "FAIL: kernel config not found (looked for rootfs/config and */linux-headers*/.config)" >&2
	exit 1
fi

echo "==> kernel config: $CFG"
echo
echo "=== required flags ==="
ok=true
for flag in CONFIG_BPF CONFIG_BPF_SYSCALL CONFIG_BPF_JIT CONFIG_BPF_LSM \
			CONFIG_DEBUG_INFO CONFIG_DEBUG_INFO_BTF CONFIG_DEBUG_INFO_BTF_MODULES \
			CONFIG_SECURITY; do
	val=$(grep -E "^${flag}=" "$CFG" || echo "")
	if [ -n "$val" ]; then
		echo "  [OK]   $val"
	else
		echo "  [FAIL] $flag not set"
		ok=false
	fi
done

echo
echo "=== CONFIG_LSM (default chain) ==="
lsm=$(grep -E '^CONFIG_LSM=' "$CFG" || echo "(not set)")
echo "  $lsm"
if echo "$lsm" | grep -q 'bpf'; then
	echo "  [OK] bpf is in the default LSM chain — active at boot with no args"
else
	echo "  [INFO] bpf NOT in default LSM chain — consumer must pass 'lsm=...,bpf' as kernel boot arg"
	echo "         (this is expected on Ubuntu/Debian/Rocky stock kernels; activation is consumer-side)"
fi

echo
if $ok; then
	echo "==> VALID — kernel has all required BPF-LSM capabilities"
	echo "    NOTE: BPF LSM activates only if 'lsm=...,bpf' is in kernel boot args."
	echo "    interpose-sandbox handles this automatically when launching Firecracker VMs."
	exit 0
else
	echo "==> INVALID — at least one required capability missing"
	exit 1
fi
