# gotty build — modern Go modules flow (replaces the old godep / go-bindata setup).
# web assets are pre-generated and committed in app/resource.go (Code generated, DO NOT EDIT),
# so they are not rebuilt here: the libapps submodule and go-bindata are no longer required.

# single source of truth for the version is the Version var in app/app.go
VERSION := $(shell grep -oE 'Version = "[0-9][^"]*"' app/app.go | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
# cloud66/central's installer fetches the tarball with dots replaced by underscores
VERSION_US := $(subst .,_,$(VERSION))

OUTPUT_DIR := ./builds
# hand-written Go files only — exclude vendored deps and the generated bindata file
GOFILES := $(shell find . -name '*.go' -not -path './vendor/*' -not -name 'resource.go')

# default target: build a local binary for the host platform
gotty: $(GOFILES) go.mod
	go build -o gotty .

# CI gate: formatting, vet, and a full build must all pass
test:
	@unformatted=$$(gofmt -l $(GOFILES)); \
	if [ -n "$$unformatted" ]; then echo "gofmt needed on:"; echo "$$unformatted"; exit 1; fi
	go vet ./...
	go build ./...

# rewrite any unformatted hand-written files in place
fmt:
	gofmt -w $(GOFILES)

# build the linux/amd64 release artifact that central installs from S3.
# CGO is disabled so the binary is static and runs across all supported Ubuntu releases.
# output: builds/gotty_linux_amd64_<version>.tar.gz containing only the gotty executable.
dist:
	mkdir -p $(OUTPUT_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o $(OUTPUT_DIR)/gotty .
	tar -czf $(OUTPUT_DIR)/gotty_linux_amd64_$(VERSION_US).tar.gz -C $(OUTPUT_DIR) gotty
	@echo "built $(OUTPUT_DIR)/gotty_linux_amd64_$(VERSION_US).tar.gz (version $(VERSION))"

clean:
	rm -f gotty
	rm -rf $(OUTPUT_DIR)

.PHONY: test fmt dist clean
