MAKEFILE_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: install
install:
	ln -sf "$(MAKEFILE_DIR)/osnx.sh" /usr/local/bin/osnx

.PHONY: uninstall
uninstall:
	rm -f /usr/local/bin/osnx