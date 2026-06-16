# gotty build.
# Local builds use the stock Go toolchain (`make` / `go build`). Release builds and
# publishing to S3 are handled by GoBob (cloud66's centralized build/publish tool) via
# the `gobob` target below. Web assets are pre-generated and committed in app/resource.go
# (Code generated, DO NOT EDIT), so go-bindata and the old libapps submodule aren't needed.

# hand-written Go files only — exclude vendored deps and the generated bindata file
GOFILES := $(shell find . -name '*.go' -not -path './vendor/*' -not -name 'resource.go')
# version is the single source of truth in app/app.go; GoBob stamps it into the binary
VERSION := $(shell grep -oE 'Version = "[0-9][^"]*"' app/app.go | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
BRANCH  := $(shell git rev-parse --abbrev-ref HEAD)
# gotty needs a pty, so it is unix-only: exclude GoBob's default windows/* targets
GOBOB_TARGETS := darwin/arm64,darwin/amd64,linux/386,linux/amd64,linux/arm,linux/arm64

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

# cross-compile every supported release target via GoBob (build only — no S3 upload).
# GoBob builds from committed state, so this needs a clean, pushed branch. To publish:
#   gobob build+push -t '$(GOBOB_TARGETS)' -v $(VERSION) -b $(BRANCH)
#   gobob publish -v $(VERSION)
gobob:
	gobob build -t '$(GOBOB_TARGETS)' -v $(VERSION) -b $(BRANCH)

clean:
	rm -f gotty

.PHONY: test fmt gobob clean
