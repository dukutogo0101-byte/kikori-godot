#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p build/web reports
"$GODOT_BIN" --headless --path . --editor --import --quit 2>&1 | tee reports/import.log
python3 -c 'import re,sys; from pathlib import Path; sys.exit(bool(re.search("SCRIPT ERROR|Parse Error|Failed to load script", Path("reports/import.log").read_text())))'
"$GODOT_BIN" --headless --path . --script tests/test_simulation.gd 2>&1 | tee reports/simulation.log
"$GODOT_BIN" --headless --path . -- --smoke-test 2>&1 | tee reports/scene.log
python3 -c 'import re,sys; from pathlib import Path; sys.exit(bool(re.search("SCRIPT ERROR|^ERROR:", Path("reports/scene.log").read_text(), re.M)))'
"$GODOT_BIN" --headless --path . --export-release Web build/web/index.html 2>&1 | tee reports/export.log
test -s build/web/index.html
test -s build/web/index.wasm
test -s build/web/index.pck
touch build/web/.nojekyll
python3 -c 'from pathlib import Path; print("Web build bytes:", sum(p.stat().st_size for p in Path("build/web").iterdir() if p.is_file()))'
