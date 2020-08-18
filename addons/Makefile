# Copyright (c) 2020, Hewlett Packard Enterprise Development LP
#

EVEREST         ?= $(shell git rev-parse --show-toplevel)
export EVEREST

KUBE_DIR                     := $(EVEREST)/kubernetes
ADDON_DIR                    := $(KUBE_DIR)/addons
ADDON_SCRIPT                 := $(ADDON_DIR)/addon.sh
ADDON_DEPLOY_SCRIPT          := $(ADDON_DIR)/deploy.sh
ADDON_UPGRADE_SCRIPT         := $(ADDON_DIR)/upgrade.sh
ADDON_ROLLBACK_SCRIPT        := $(ADDON_DIR)/rollback.sh
ADDON_TEARDOWN_SCRIPT        := $(ADDON_DIR)/teardown.sh
ADDON_GEN_ADDON_SCRIPT       := $(ADDON_DIR)/gen-addon.sh
ADDON_RECONFIGURE_SCRIPT     := $(ADDON_DIR)/reconfigure.sh

REPO                         := bluedata
export REPO

## Pass DEBUG=true to enable debug mode.
DEBUG                        := "false"

.PHONY: 

tools-%:
	$(V)set -e; \
$(ADDON_SCRIPT) tools $*

build-%: tools-build
	$(V)set -e; \
$(ADDON_SCRIPT) $* build

push-%: build-% tools-push ## VERIFY: if we need to push tools before we push addon
	$(V)set -e; \
$(ADDON_SCRIPT) $* push

## Generate new Add-on.
generate-%:
	$(V)set -e; \
$(ADDON_GEN_ADDON_SCRIPT) $* $(VERSION)

## Debugging
deploy-%: build-%
	$(V)set -e; \
$(ADDON_DEPLOY_SCRIPT) $* $(DEBUG)

upgrade-%: build-%
	$(V)set -e; \
$(ADDON_UPGRADE_SCRIPT) $* $(DEBUG)

reconfigure-%: build-%
	$(V)set -e; \
$(ADDON_RECONFIGURE_SCRIPT) $* $(DEBUG)

rollback-%: build-%
	$(V)set -e; \
$(ADDON_ROLLBACK_SCRIPT) $* $(DEBUG)

teardown-%: build-%
	$(V)set -e; \
$(ADDON_TEARDOWN_SCRIPT) $*