#!/usr/bin/env bash
# build.sh — build a specific flavor of interpose-kernel
#
# Usage:
#   ./build.sh <flavor> [arch]
#
# Where <flavor> is one of: ubuntu, debian, rocky
# And [arch] is one of: arm64 (default), amd64
#
# Reads flavors/<flavor>/flavor.env to learn which kernel package to fetch,
# which mirror, which signing key. Dispatches to Dockerfile.deb (Ubuntu,
# Debian) or Dockerfile.rpm (Rocky) based on DISTRO_FAMILY.
#
# Output image: ${DOCKER_ORG}/${IMAGE_NAME}:${TAG_PREFIX}-bpf-lsm-${VERSION_TAG}
# (e.g. startaworldpeace/interpose-kernel:ubuntu-24.04-bpf-lsm-v0.1.0)

set -euo pipefail

if [ $# -lt 1 ]; then
	echo "usage: $0 <flavor> [arch]" >&2
	echo "       flavor: ubuntu | debian | rocky" >&2
	echo "       arch:   arm64 (default) | amd64" >&2
	exit 64
fi

FLAVOR="$1"
ARCH="${2:-arm64}"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
FLAVOR_DIR="${REPO_ROOT}/flavors/${FLAVOR}"

if [ ! -d "${FLAVOR_DIR}" ]; then
	echo "unknown flavor: ${FLAVOR}" >&2
	echo "available: $(ls "${REPO_ROOT}/flavors")" >&2
	exit 64
fi

ENV_FILE="${FLAVOR_DIR}/flavor.env"
if [ ! -f "${ENV_FILE}" ]; then
	echo "missing: ${ENV_FILE}" >&2
	exit 1
fi

# Source the flavor's env file (KERNEL_VERSION, DEB_MIRROR, etc.)
set -a
. "${ENV_FILE}"
set +a

# Per-build / publish settings (overridable)
DOCKER_ORG="${DOCKER_ORG:-startaworldpeace}"
IMAGE_NAME="${IMAGE_NAME:-interpose-kernel}"
VERSION_TAG="${VERSION_TAG:-v0.1.0}"
TAG="${DOCKER_ORG}/${IMAGE_NAME}:${TAG_PREFIX}-bpf-lsm-${VERSION_TAG}"

# Pick the right Dockerfile
case "${DISTRO_FAMILY}" in
	deb) DOCKERFILE="${REPO_ROOT}/Dockerfile.deb" ;;
	rpm) DOCKERFILE="${REPO_ROOT}/Dockerfile.rpm" ;;
	*) echo "unsupported DISTRO_FAMILY: ${DISTRO_FAMILY}" >&2; exit 1 ;;
esac

if [ ! -f "${DOCKERFILE}" ]; then
	echo "missing: ${DOCKERFILE}" >&2
	exit 1
fi

echo "==> building ${TAG}"
echo "    flavor:   ${FLAVOR}"
echo "    arch:     ${ARCH}"
echo "    family:   ${DISTRO_FAMILY}"
echo "    docker:   ${DOCKERFILE}"
echo "    config:   ${ENV_FILE}"
echo

# Build all the --build-arg flags from the sourced env file. Any variable
# whose name is one of the well-known per-flavor parameters gets passed
# through.
BUILD_ARGS=()
for var in \
	FLAVOR_NAME DISTRO_FAMILY TAG_PREFIX BUILDER_IMAGE \
	KERNEL_VARIANT KERNEL_VERSION KERNEL_VERSION_FULL KERNEL_DEB_DELTA KERNEL_DEB_PACKAGES \
	UBUNTU_RELEASE UBUNTU_CODENAME DEBIAN_RELEASE DEBIAN_CODENAME \
	ROCKY_RELEASE ROCKY_MINOR RPM_MIRROR GPG_KEY_URL KERNEL_RPMS \
; do
	val="${!var:-}"
	if [ -n "${val}" ]; then
		BUILD_ARGS+=(--build-arg "${var}=${val}")
	fi
done

docker buildx build \
	--platform "linux/${ARCH}" \
	-f "${DOCKERFILE}" \
	"${BUILD_ARGS[@]}" \
	-t "${TAG}" \
	--load \
	"${REPO_ROOT}"

echo
echo "==> built: ${TAG}"
echo "==> next: ./scripts/validate.sh ${TAG}"
