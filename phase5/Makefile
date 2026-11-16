.PHONY: all build test pack
all: build
build:
	python3 build.py
	python3 verify_elf.py
test:
	python3 test_runtime.py
pack: build
	python3 ../phase4b/doom/pack_image.py artifacts/doom-rv32i.elf build/load-image
