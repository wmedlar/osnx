MAKEFILE_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: build
build: lint
	mkdir -p bin
	shc -f osnx.sh -o bin/osnx -rv

.PHONY: lint
lint:
	command -v shellcheck || brew install shellcheck
	shellcheck -ax osnx.sh

.PHONY: install
install: dependencies
	ln -sf "$(MAKEFILE_DIR)/osnx.sh" /usr/local/bin/osnx

.PHONY: dependencies
dependencies:
	command -v yq || brew install yq

.PHONY: uninstall
uninstall:
	rm -f /usr/local/bin/osnx
