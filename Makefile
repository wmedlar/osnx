MAKEFILE_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: lint
lint:
	command -v shellcheck || brew install shellcheck
	shellcheck *.sh

.PHONY: install
install: dependencies
	ln -sf "$(MAKEFILE_DIR)/osnx.sh" /usr/local/bin/osnx

.PHONY: dependencies
dependencies:
	command -v yq || brew install yq

.PHONY: uninstall
uninstall:
	rm -f /usr/local/bin/osnx