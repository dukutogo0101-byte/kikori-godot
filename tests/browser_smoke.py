#!/usr/bin/env python3
"""Real WebGL browser verification: touch UI, production, upgrades, reload/save, failures.

Runs in CI against the actual Godot Web export. Screenshots and results are artifacts.
Chromium is an Android-sized approximation; WebKit checks the Safari engine.
Real device certification is a separate manual check.
"""
import argparse
import base64
import json
from pathlib import Path
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright


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
    preview = page.screenshot(path=f"reports/{name}-portrait.png")
    # Inline diagnostic lets repository-only clients review the rendered scene.
    print("KIKORI_PREVIEW " + name + " " + base64.b64encode(preview).decode(), flush=True)
    # Rush and wait for the full physical production loop; diagnostics are read-only.
    tap("boost")
    try:
        page.wait_for_function("window.kikoriState && window.kikoriState.processed >= 3 && window.kikoriState.money >= 50", timeout=75000, polling=500)
    except Exception:
        print("KIKORI_TIMEOUT_STATE", page.evaluate("({state:window.kikoriState,ui:window.kikoriUi,hidden:document.hidden})"), flush=True)
        preview = page.screenshot(path=f"reports/{name}-failure.png")
        print("KIKORI_PREVIEW failure " + base64.b64encode(preview).decode(), flush=True)
        raise
    before = page.evaluate("window.kikoriState")
    tap("wood")
    page.wait_for_function("window.kikoriState.levels.wood === 1", timeout=15000)
    assert page.evaluate("window.kikoriState.money") <= before["money"] + 12 - 50, "Upgrade did not charge funds"
    saved = page.evaluate("JSON.parse(localStorage.getItem('kikori.phase1.v1'))")
    assert saved["levels"]["wood"] == 1
    page.reload(wait_until="domcontentloaded")
    page.wait_for_function("window.kikoriReady === true", timeout=90000)
    page.wait_for_function("window.kikoriState && window.kikoriState.levels.wood === 1", timeout=15000)
    assert page.evaluate("window.kikoriState.processed") >= saved["processed"], "Reload lost progress"
    page.screenshot(path=f"reports/{name}-upgraded.png")
    # Wide layout: controls remain visible next to the island.
    page.set_viewport_size({"width": 844, "height": 390})
    page.wait_for_timeout(1500)
    page.screenshot(path=f"reports/{name}-landscape.png")
    # Corrupted state must fall back to a playable fresh game.
    page.evaluate("localStorage.setItem('kikori.phase1.v1', '{invalid json')")
    page.reload(wait_until="domcontentloaded")
    page.wait_for_function("window.kikoriReady === true", timeout=90000)
    assert not errors, "Browser errors: " + "\n".join(errors)
    result = {"engine": name, "production": before, "persisted_level": saved["levels"]["wood"], "errors": errors}
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
                options = {"headless": True}
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
