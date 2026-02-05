SHELL=/bin/bash
LDFLAGS=-ldflags "-s -w"

CACHE_DIR ?= cache
OUT_DIR ?= out
ASSET_DIR ?= assets

GOPATH=$(shell go env GOPATH)
GOBIN=$(GOPATH)/bin

REPO_OWNER := aquasecurity

u := $(if $(update),-u)

$(GOBIN)/wire:
	go install github.com/google/wire/cmd/wire@v0.5.0

.PHONY: wire
wire: $(GOBIN)/wire
	wire gen ./...

$(GOBIN)/mockery:
	go install github.com/knqyf263/mockery/cmd/mockery@latest

.PHONY: mock
mock: $(GOBIN)/mockery
	$(GOBIN)/mockery -all -inpkg -case=snake

.PHONY: deps
deps:
	go get ${u} -d
	go mod tidy

$(GOBIN)/golangci-lint:
	curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(GOBIN) v1.63.4

.PHONY: test
test:
	go test -v -short -race -timeout 30s -coverprofile=coverage.txt -covermode=atomic ./...

.PHONY: lint
lint: $(GOBIN)/golangci-lint
	$(GOBIN)/golangci-lint run

.PHONY: lintfix
lintfix: $(GOBIN)/golangci-lint
	$(GOBIN)/golangci-lint run --fix

.PHONY: build
build:
	go build $(LDFLAGS) ./cmd/trivy-db

.PHONY: clean
clean:
	rm -rf integration/testdata/fixtures/

$(GOBIN)/bbolt:
	go install go.etcd.io/bbolt/cmd/bbolt@v1.3.5

trivy-db:
	make build

.PHONY: db-fetch-langs
db-fetch-langs:
	rm -rf $(CACHE_DIR)/ruby-advisory-db && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b master https://github.com/rubysec/ruby-advisory-db.git $(CACHE_DIR)/ruby-advisory-db
	rm -rf $(CACHE_DIR)/php-security-advisories && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b master https://github.com/FriendsOfPHP/security-advisories.git $(CACHE_DIR)/php-security-advisories
	rm -rf $(CACHE_DIR)/nodejs-security-wg && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/nodejs/security-wg.git $(CACHE_DIR)/nodejs-security-wg
	rm -rf $(CACHE_DIR)/bitnami-vulndb && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/bitnami/vulndb.git $(CACHE_DIR)/bitnami-vulndb
	rm -rf $(CACHE_DIR)/ghsa && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/github/advisory-database.git $(CACHE_DIR)/ghsa
	rm -rf $(CACHE_DIR)/govulndb && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b master https://github.com/golang/vulndb.git $(CACHE_DIR)/govulndb
	## required to convert GHSA Swift repo links to Cocoapods package names
	rm -rf $(CACHE_DIR)/cocoapods-specs && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b master https://github.com/CocoaPods/Specs.git $(CACHE_DIR)/cocoapods-specs
	rm -rf $(CACHE_DIR)/k8s-cve-feed && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/kubernetes-sigs/cve-feed-osv.git $(CACHE_DIR)/k8s-cve-feed
	rm -rf $(CACHE_DIR)/julia && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b generated/osv https://github.com/JuliaLang/SecurityAdvisories.jl.git $(CACHE_DIR)/julia

.PHONY: db-build
db-build: trivy-db
	./trivy-db build --cache-dir ./$(CACHE_DIR) --output-dir ./$(OUT_DIR) --update-interval 24h

.PHONY: db-compact
db-compact: $(GOBIN)/bbolt ./$(OUT_DIR)/trivy.db
	mkdir -p ./$(ASSET_DIR)
	$(GOBIN)/bbolt compact -o ./$(ASSET_DIR)/trivy.db ./$(OUT_DIR)/trivy.db
	cp ./$(OUT_DIR)/metadata.json ./$(ASSET_DIR)/metadata.json
	rm -rf ./$(OUT_DIR)

.PHONY: db-compress
db-compress: $(ASSET_DIR)/trivy.db $(ASSET_DIR)/metadata.json
	tar cvzf ./$(ASSET_DIR)/db.tar.gz -C $(ASSET_DIR) trivy.db metadata.json

.PHONY: db-clean
db-clean:
	rm -rf $(CACHE_DIR) $(OUT_DIR) $(ASSET_DIR)

.PHONY: db-fetch-vuln-list
db-fetch-vuln-list:
	rm -rf $(CACHE_DIR)/vuln-list && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/$(REPO_OWNER)/vuln-list.git $(CACHE_DIR)/vuln-list
	rm -rf $(CACHE_DIR)/vuln-list-redhat && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/$(REPO_OWNER)/vuln-list-redhat.git $(CACHE_DIR)/vuln-list-redhat
	rm -rf $(CACHE_DIR)/vuln-list-debian && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/$(REPO_OWNER)/vuln-list-debian.git $(CACHE_DIR)/vuln-list-debian
	rm -rf $(CACHE_DIR)/vuln-list-nvd && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/$(REPO_OWNER)/vuln-list-nvd.git $(CACHE_DIR)/vuln-list-nvd
	rm -rf $(CACHE_DIR)/vuln-list-aqua && GIT_TERMINAL_PROMPT=0 git clone --depth 1 -b main https://github.com/$(REPO_OWNER)/vuln-list-aqua.git $(CACHE_DIR)/vuln-list-aqua
