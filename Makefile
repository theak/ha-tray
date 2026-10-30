APP := build/HA Tray.app
INSTALL_DIR := $(HOME)/Applications

.PHONY: build run install test

build:
	scripts/build-app.sh

run: build
	pkill -x HATray || true
	open "$(APP)"

install: build
	pkill -x HATray || true
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/HA Tray.app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/HA Tray.app"

test:
	swift test
