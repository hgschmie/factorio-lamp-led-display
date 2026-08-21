.PHONY: test test-go test-lua test-firmware build-firmware compose-config

test: test-go test-lua test-firmware

test-go:
	cd daemon && go test ./...

test-lua:
	cd factorio-mod/tests && lua test_lib.lua

test-firmware:
	cd firmware && PLATFORMIO_CORE_DIR=.pio-core pio test -e native

build-firmware:
	cd firmware && PLATFORMIO_CORE_DIR=.pio-core pio run -e esp32-c3-supermini

compose-config:
	docker compose config --quiet
