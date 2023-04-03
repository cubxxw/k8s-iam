# Copyright © 2022 Alibaba Group Holding Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ==============================================================================
# define the default goal
#

.DEFAULT_GOAL := help

.PHONY: all
all: tidy gen add-copyright format lint cover build

# ==============================================================================
# Build set

ROOT_PACKAGE=github.com/cubxxw/k8s-iam
VERSION_PACKAGE=github.com/cubxxw/k8s-iam/pkg/version

Dirs=$(shell ls)
GIT_TAG := $(shell git describe --exact-match --tags --abbrev=0  2> /dev/null || echo untagged)
GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)

BUILD_SCRIPTS := scripts/build.sh

# ==============================================================================
# Includes

include scripts/make-rules/common.mk # make sure include common.mk at the first include line
include scripts/make-rules/golang.mk
include scripts/make-rules/image.mk
include scripts/make-rules/copyright.mk
include scripts/make-rules/gen.mk
include scripts/make-rules/ca.mk
include scripts/make-rules/release.mk
include scripts/make-rules/swagger.mk
include scripts/make-rules/dependencies.mk
include scripts/make-rules/tools.mk

# ==============================================================================
# Usage

define USAGE_OPTIONS

Options:

  DEBUG            Whether or not to generate debug symbols. Default is 0.

  BINS             Binaries to build. Default is all binaries under cmd.
                   This option is available when using: make {build}(.multiarch)
                   Example: make build BINS="sealer sealctl"

  PLATFORMS        Platform to build for. Default is linux_arm64 and linux_amd64.
                   This option is available when using: make {build}.multiarch
                   Example: make build.multiarch PLATFORMS="linux_arm64 linux_amd64"

  V                Set to 1 enable verbose build. Default is 0.
endef
export USAGE_OPTIONS

# ==============================================================================
# Targets

## build: Build binaries by default
.PHONY: build
build: clean
	@$(MAKE) go.build

## fmt: Run go fmt against code.
.PHONY: fmt
fmt:
	go fmt ./...

## vet: Run go vet against code.
.PHONY: vet
vet:
	go vet ./...

## push: Push to remote repository
.PHONY: push
push:
	@sh scripts/gitsync.sh

## lint: Run go lint against code.
.PHONY: lint
lint:
	golangci-lint run -v ./...

## style: code style -> fmt,vet,lint
.PHONY: style
style: fmt vet lint

## linux-amd64: Build binaries for Linux (amd64)
linux-amd64: clean
	@echo "Building sealer and seautil binaries for Linux (amd64)"
	@GOOS=linux GOARCH=amd64 $(BUILD_SCRIPTS) $(GIT_TAG)

## linux-arm64: Build binaries for Linux (arm64)
linux-arm64: clean
	@echo "Building sealer and seautil binaries for Linux (arm64)"
	@GOOS=linux GOARCH=arm64 $(BUILD_SCRIPTS) $(GIT_TAG)

## build-in-docker: sealer should be compiled in linux platform, otherwise there will be GraphDriver problem.
build-in-docker:
	@docker run --rm -v ${PWD}:/usr/src/sealer -w /usr/src/sealer registry.cn-qingdao.aliyuncs.com/sealer-io/sealer-build:v1 make linux

## gen: Generate all necessary files.
.PHONY: gen
gen:
	@$(MAKE) gen.run

## verify-copyright: Verify the license headers for all files.
.PHONY: verify-copyright
verify-license:
	@$(MAKE) copyright.verify

## add-copyright: Add copyright ensure source code files have license headers.
.PHONY: add-copyright
add-license:
	@$(MAKE) copyright.add

gosec: install-gosec
	$(GOSEC_BIN) ./...

## tools: Install dependent tools.
.PHONY: tools
tools:
	@$(MAKE) tools.install

## install-deepcopy-gen: check license if not exist install deepcopy-gen tools.
install-deepcopy-gen:
ifeq (, $(shell which deepcopy-gen))
	{ \
	set -e ;\
	LICENSE_TMP_DIR=$$(mktemp -d) ;\
	cd $$LICENSE_TMP_DIR ;\
	go mod init tmp ;\
	go get -v k8s.io/code-generator/cmd/deepcopy-gen ;\
	rm -rf $$LICENSE_TMP_DIR ;\
	}
DEEPCOPY_BIN=$(GOBIN)/deepcopy-gen
else
DEEPCOPY_BIN=$(shell which deepcopy-gen)
endif

# BOILERPLATE := scripts/boilerplate.go.txt
# INPUT_DIR := github.com/sealerio/sealer/types/api

## deepcopy: generate deepcopy code.
deepcopy: install-deepcopy-gen
	$(DEEPCOPY_BIN) \
      --input-dirs="$(INPUT_DIR)/v1" \
      -O zz_generated.deepcopy   \
      --go-header-file "$(BOILERPLATE)" \
      --output-base "${GOPATH}/src"
	$(DEEPCOPY_BIN) \
	  --input-dirs="$(INPUT_DIR)/v2" \
	  -O zz_generated.deepcopy   \
	  --go-header-file "$(BOILERPLATE)" \
	  --output-base "${GOPATH}/src"

## clean: Remove all files that are created by building. 
.PHONY: clean
clean:
	@$(MAKE) go.clean

## help: Show this help info.
.PHONY: help
help: Makefile
	$(call makehelp)

## all-help: Show all help details info.
.PHONY: all-help
all-help: go.help copyright.help tools.help image.help help
	$(call makeallhelp)