# interpose-kernel — three flavors, unified pipeline
#
# Repackages distro kernels (Ubuntu, Debian, Rocky) into OCI images with
# the interpose-kernel artifact layout. See docs/decisions/0003-three-flavor-strategy.md.

DOCKER_ORG   ?= startaworldpeace
IMAGE_NAME   ?= interpose-kernel
VERSION_TAG  ?= v0.1.0
ARCH         ?= arm64

.PHONY: help ubuntu debian rocky all validate push-ubuntu push-debian push-rocky push-all clean

help:
	@echo "interpose-kernel — three flavors, one pipeline."
	@echo
	@echo "Build:"
	@echo "  make ubuntu         # repackage Ubuntu 24.04 LTS kernel"
	@echo "  make debian         # repackage Debian 12 Bookworm kernel"
	@echo "  make rocky          # repackage Rocky Linux 9 kernel"
	@echo "  make all            # all three"
	@echo
	@echo "Validate (works for all flavors via shared scripts/validate.sh):"
	@echo "  make validate FLAVOR=ubuntu   # validate the most recent build of <flavor>"
	@echo
	@echo "Publish:"
	@echo "  make push-ubuntu"
	@echo "  make push-debian"
	@echo "  make push-rocky"
	@echo "  make push-all"
	@echo
	@echo "Maintenance:"
	@echo "  make clean          # remove local build cache"
	@echo
	@echo "Overrides:"
	@echo "  make ubuntu VERSION_TAG=v0.1.5 DOCKER_ORG=interposehq"
	@echo "  make all ARCH=amd64"

ubuntu:
	DOCKER_ORG=$(DOCKER_ORG) IMAGE_NAME=$(IMAGE_NAME) VERSION_TAG=$(VERSION_TAG) \
	  ./build.sh ubuntu $(ARCH)

debian:
	DOCKER_ORG=$(DOCKER_ORG) IMAGE_NAME=$(IMAGE_NAME) VERSION_TAG=$(VERSION_TAG) \
	  ./build.sh debian $(ARCH)

rocky:
	DOCKER_ORG=$(DOCKER_ORG) IMAGE_NAME=$(IMAGE_NAME) VERSION_TAG=$(VERSION_TAG) \
	  ./build.sh rocky $(ARCH)

all: ubuntu debian rocky

validate:
	@if [ -z "$(FLAVOR)" ]; then \
		echo "usage: make validate FLAVOR=<ubuntu|debian|rocky>"; exit 1; \
	fi
	DOCKER_ORG=$(DOCKER_ORG) IMAGE_NAME=$(IMAGE_NAME) \
	  ./scripts/validate.sh \
	  "$(DOCKER_ORG)/$(IMAGE_NAME):$(shell . ./flavors/$(FLAVOR)/flavor.env && echo $$TAG_PREFIX)-bpf-lsm-$(VERSION_TAG)"

push-ubuntu:
	docker push $(DOCKER_ORG)/$(IMAGE_NAME):ubuntu-24.04-bpf-lsm-$(VERSION_TAG)

push-debian:
	docker push $(DOCKER_ORG)/$(IMAGE_NAME):debian-12-bpf-lsm-$(VERSION_TAG)

push-rocky:
	docker push $(DOCKER_ORG)/$(IMAGE_NAME):rocky-9-bpf-lsm-$(VERSION_TAG)

push-all: push-ubuntu push-debian push-rocky

clean:
	rm -rf .build/
