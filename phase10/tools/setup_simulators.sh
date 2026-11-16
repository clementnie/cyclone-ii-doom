#!/bin/sh
# User-space simulator install; no sudo or system package modification.
set -eu
mkdir -p /tmp/phase9-tools
for package in iverilog-13.0-1-x86_64 verilator-5.054-1-x86_64; do
 curl -fL "https://fastly.mirror.pkgbuild.com/extra/os/x86_64/$package.pkg.tar.zst" -o "/tmp/$package.pkg.tar.zst"
 tar -xf "/tmp/$package.pkg.tar.zst" -C /tmp/phase9-tools
done
