#!/usr/bin/env python3
"""Real WebGL browser verification: touch UI, production, upgrades, reload/save, failures.

Runs in CI against the actual Godot Web export. Screenshots and results are artifacts.
Chromium is an Android-sized approximation; WebKit checks the Safari engine.
Real device certification is a separate manual check.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright


def emit_preview(name, content):
    # Xvfb/driver pipes may be nonblocking. Small blocking writes avoid truncating PNGs.
    os.set_blocking(sys.stdout.fileno(), True)
    encoded = base64.b64encode(content).decode()
    print("KIKORI_PREVIEW_BEGIN " + name, flush=True)
    for offset in range(0, len(encoded), 2048):
        print("KIKORI_PREVIEW_DATA " + name + " " + encoded[offset:offset + 2048], flush=True)
    print("KIKORI_PREVIEW_END " + name, flush=True)


def inspect_browser(browser, url, name):
    context = browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=1,
                                  is_mobile=True, has_touch=True, locale="ja-JP")
    page = context.new_page()
    errors = []
    page.on("pageerror", lambda error: (errors.append(str(error)), print("PAGE_ERROR:", error, flush=True)))
    page.on("console", lambda message: (errors.append(message.text), print("CONSOLE_ERROR:", message.text, flush=True)) if message.type == "error" else None)
    page.goto(url, wait_until="domcontentloaded")
    page.wait_for_function("window.kikoriReady === true", timeout=90000)
    page.wait_for_timeout(1000)
    assert page.locator("#loading").is_hidden(), "Loading shell did not dismiss"
    def tap(key):
        ui = page.evaluate("window.kikoriUi")
        bounds = page.locator("#canvas").bounding_box()
        position = ui[key]
        page.touchscreen.tap(bounds["x"] + position["x"] / ui["width"] * bounds["width"],
                             bounds["y"] + position["y"] / ui["height"] * bounds["height"])
    page.wait_for_function("window.kikoriUi && window.kikoriUi.start && window.kikoriUi.start.y > 0", timeout=15000)
    tap("start")
    page.wait_for_function("window.kikoriState && window.kikoriState.saved", timeout=15000)
    print("KIKORI_INITIAL_STATE", page.evaluate("window.kikoriState"), flush=True)
    # WebKitGTK's screenshot readback triggers framebuffer validation errors on Mesa.
    # Keep strict console checks, and exercise WebKit without the capture API.
    if name == "chromium":
        preview = page.screenshot(path=f"reports/{name}-portrait.png")
        emit_preview(name, preview)
    # Rush and wait for the full physical production loop; diagnostics are read-only.
    tap("boost")
    try:
        page.wait_for_function("window.kikoriState && window.kikoriState.processed >= 3 && window.kikoriState.money >= 50", timeout=75000, polling=500)
    except Exception:
        print("KIKORI_TIMEOUT_STATE", page.evaluate("({state:window.kikoriState,ui:window.kikoriUi,hidden:document.hidden})"), flush=True)
        if name == "chromium":
            preview = page.screenshot(path=f"reports/{name}-failure.png")
            emit_preview("failure", preview)
        raise
    before = page.evaluate("window.kikoriState")
    tap("wood")
    page.wait_for_function("window.kikoriState.levels.wood === 1", timeout=15000)
    after = page.evaluate("window.kikoriState")
    assert after["money"] == before["money"] + (after["processed"] - before["processed"]) * 12 - 50, "Upgrade payment must account for concurrent sales"
    saved = page.evaluate("JSON.parse(localStorage.getItem('kikori.phase1.v1'))")
    assert saved["levels"]["wood"] == 1
    page.reload(wait_until="domcontentloaded")
    page.wait_for_function("window.kikoriReady === true", timeout=90000)
    page.wait_for_function("window.kikoriState && window.kikoriState.levels.wood === 1", timeout=15000)
    assert page.evaluate("window.kikoriState.processed") >= saved["processed"], "Reload lost progress"
    if name == "chromium":
        page.screenshot(path=f"reports/{name}-upgraded.png")
    # Wide layout: controls remain visible next to the island.
    page.set_viewport_size({"width": 844, "height": 390})
    page.wait_for_timeout(1500)
    if name == "chromium":
        page.screenshot(path=f"reports/{name}-landscape.png")
    # Corrupted state must fall back to a playable fresh game.
    page.evaluate("localStorage.setItem('kikori.phase1.v1', '{invalid json')")
    page.reload(wait_until="domcontentloaded")
    page.wait_for_function("window.kikoriReady === true", timeout=90000)
    gl_error = page.evaluate("document.getElementById('canvas').getContext('webgl2').getError()")
    print("KIKORI_RENDER_STATE", name, page.evaluate("window.kikoriRenderer"), flush=True)
    assert gl_error == 0, f"WebGL error flag: {gl_error}"
    assert not errors, "Browser errors: " + "\n".join(errors)
    result = {"engine": name, "production": before, "persisted_level": saved["levels"]["wood"], "errors": errors,
              "webgl_error": gl_error, "renderer": page.evaluate("window.kikoriRenderer")}
    context.close()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url")
    parser.add_argument("--engine", choices=["chromium", "webkit", "all"], default="all")
    args = parser.parse_args()
    Path("reports").mkdir(exist_ok=True)
    server = None
    url = args.url
    if not url:
        handler = partial(SimpleHTTPRequestHandler, directory="build/web")
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        url = f"http://127.0.0.1:{server.server_port}/"
    results = []
    try:
        with sync_playwright() as playwright:
            engines = ["chromium", "webkit"] if args.engine == "all" else [args.engine]
            for engine in engines:
                # GTK WebKit's headless screenshot path has a Mesa framebuffer issue.
                # CI runs the normal WebKit window under Xvfb instead.
                options = {"headless": engine != "webkit"}
                if engine == "chromium":
                    options["args"] = ["--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
                browser = getattr(playwright, engine).launch(**options)
                try:
                    results.append(inspect_browser(browser, url, engine))
                finally:
                    browser.close()
        Path("reports/browser-results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
        print(json.dumps(results, ensure_ascii=False, indent=2))
    finally:
        if server:
            server.shutdown()


if __name__ == "__main__":
    main()
