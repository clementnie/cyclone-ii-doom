CC = clang
FLAGS = --target=riscv32-unknown-elf -march=rv32i -mabi=ilp32 -mno-relax -msmall-data-limit=0 -Os -ffreestanding -fno-builtin -nostdlib -DCMAP256 -DDOOMGENERIC_RESX=320 -DDOOMGENERIC_RESY=200 -Iinclude -Iupstream/doomgeneric
.PHONY: all engine platform-test
all: platform-test engine
build:
	mkdir -p build
platform-test: | build
	$(CC) $(FLAGS) -fuse-ld=lld -Wl,-T,platform_test.ld,-Map,build/platform-test.map -o build/platform-test.elf ../firmware/start.S platform.c platform_test.c integer_runtime.c
	llvm-size build/platform-test.elf
engine:
	python3 compile_engine.py
	llvm-size build/doom-engine.rv32i.o
	llvm-nm -u build/doom-engine.rv32i.o > unresolved.txt
.PHONY: engine-link
engine-link: engine
	$(CC) $(FLAGS) -c ../firmware/start.S -o build/start.o
	$(CC) $(FLAGS) -c engine_main.c -o build/engine_main.o
	$(CC) $(FLAGS) -c integer_runtime.c -o build/integer_runtime.o
	ld.lld -m elf32lriscv -T engine.ld --error-limit=0 -Map=build/engine.map -o build/doom.elf build/start.o build/engine_main.o build/integer_runtime.o build/doom-engine.rv32i.o
.PHONY: native-tests
native-tests: | build
	clang -O2 integer_runtime.c test_integer_runtime.c -o build/test_integer_runtime
	build/test_integer_runtime > ../reports/integer-runtime-test.log
	python3 test_packer.py > ../reports/packer-test.log
	cat ../reports/integer-runtime-test.log ../reports/packer-test.log
