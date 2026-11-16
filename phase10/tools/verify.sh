#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
python3 phase10/tools/test_runtime.py
python3 phase10/tools/test_renderer.py
python3 phase10/tools/test_patches.py
python3 phase10/tools/focused.py
python3 phase10/tools/test_upload_hotfix.py
python3 phase10/tools/test_video.py
python3 phase10/tools/integrated_fast.py
python3 phase10/tools/regress.py tb_keyboard
python3 phase10/tools/regress.py tb_mmio
python3 phase10/tools/test_upload_integrated.py
