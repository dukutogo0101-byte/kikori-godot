#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
rm -rf build/web
mkdir -p build/web reports
rm -f reports/*.log
node tests/test_web_guard.cjs
node tests/test_pwa.cjs
"$GODOT_BIN" --headless --path . --editor --import --quit 2>&1 | tee reports/import.log
python3 -c 'import re,sys; from pathlib import Path; sys.exit(bool(re.search("SCRIPT ERROR|Parse Error|Failed to load script", Path("reports/import.log").read_text())))'
"$GODOT_BIN" --headless --path . --script tools/bake_assets.gd -- --smoke-test 2>&1 | tee reports/bake.log
python3 -c 'import re,sys; from pathlib import Path; sys.exit(bool(re.search("SCRIPT ERROR|^ERROR:", Path("reports/bake.log").read_text(), re.M)))'
"$GODOT_BIN" --headless --path . --editor --import --quit 2>&1 | tee reports/baked-import.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_direct_loop.gd 2>&1 | tee reports/direct-loop.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_adventure.gd 2>&1 | tee reports/simulation.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_tools.gd 2>&1 | tee reports/tools.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_automation.gd 2>&1 | tee reports/automation.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_watersheds.gd 2>&1 | tee reports/watersheds.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_facilities.gd 2>&1 | tee reports/facilities.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_transport.gd -- --smoke-test 2>&1 | tee reports/transport.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_building_growth.gd -- --smoke-test 2>&1 | tee reports/buildings.log
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_logistics.gd 2>&1 | tee reports/logistics.log
python3 -c 'import re,sys; from pathlib import Path; sys.exit(any(re.search("SCRIPT ERROR|^ERROR:|failures=[1-9]", p.read_text(), re.M) for p in Path("reports").glob("*.log")))'
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_road_building.gd -- --smoke-test 2>&1 | tee reports/road-building.log
python3 -c 'import re,sys; from pathlib import Path; sys.exit(bool(re.search("SCRIPT ERROR|^ERROR:|failures=[1-9]", Path("reports/road-building.log").read_text(), re.M)))'
timeout 30s "$GODOT_BIN" --headless --path . -- --smoke-test 2>&1 | tee reports/scene.log
python3 -c 'import re,sys; from pathlib import Path; sys.exit(bool(re.search("SCRIPT ERROR|^ERROR:", Path("reports/scene.log").read_text(), re.M)))'
timeout 180s "$GODOT_BIN" --headless --path . --script tests/test_scene.gd -- --smoke-test 2>&1 | tee reports/scene-events.log
python3 -c 'import re,sys; from pathlib import Path; sys.exit(bool(re.search("SCRIPT ERROR|^ERROR:", Path("reports/scene-events.log").read_text(), re.M)))'
"$GODOT_BIN" --headless --path . --export-release Web build/web/index.html 2>&1 | tee reports/export.log
test -s build/web/index.html
test -s build/web/index.wasm
test -s build/web/index.pck
cp web/framebuffer_guard.js build/web/framebuffer_guard.js
python3 tools/build_pwa.py
