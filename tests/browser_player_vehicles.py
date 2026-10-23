#!/usr/bin/env python3
"""Focused Android-sized UI purchases, distinct vehicles, cargo and reload check."""
import argparse
import base64
import gzip
import json
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_smoke import ready, state, tap, KEY
from browser_expansion import visible_tap


def run(browser, url):
    errors = []
    screenshots = []
    for scenario in ['purchase', 'loaded']:
        fixture = json.loads(Path('reports/player-vehicle-start.json' if scenario == 'purchase' else 'reports/player-vehicle-loaded-2.json').read_text())
        # Purchase scenario deliberately exercises the previous published save schema.
        if scenario == 'purchase':
            fixture['version'] = 9
            fixture.pop('vehicle_tier', None)
        context = browser.new_context(viewport={'width': 390, 'height': 844}, has_touch=True, is_mobile=True, locale='ja-JP')
        context.add_init_script('if(!localStorage.getItem(' + json.dumps(KEY) + '))localStorage.setItem(' + json.dumps(KEY) + ',' + json.dumps(json.dumps(fixture)) + ');')
        page = context.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
        try:
            page.goto(url)
            ready(page)
            assert state(page)['version'] == 10 and state(page)['conserved']
            if scenario == 'purchase':
                assert state(page)['vehicle_tier'] == 0
                for tier, speed, capacity, price in [(1, 13, 512, 20000), (2, 20, 1536, 120000)]:
                    before = state(page)['money']
                    tap(page, 'menu')
                    visible_tap(page, 'vehicle')
                    page.wait_for_function('(n) => window.kikoriState.vehicle_tier === n', arg=tier)
                    assert state(page)['money'] == before - price
                    assert state(page)['speed'] == speed and state(page)['capacity'] == capacity
                    page.screenshot(path=f'reports/player-vehicle-{tier}-menu.png')
                    tap(page, 'close')
                    page.wait_for_function('(n) => window.kikoriState.objects.vehicle_visible === n', arg=tier)
                    page.wait_for_timeout(500)
                    image = page.screenshot(path=f'reports/player-vehicle-{tier}.png')
                    screenshots.append(image)
                # The init script only seeds a new context. Reload must use the saved purchase.
                page.evaluate("window.dispatchEvent(new Event('blur'))")
                final = state(page)['money']
                saved = page.evaluate('(key) => localStorage.getItem(key)', KEY)
                saved_data = json.loads(gzip.decompress(base64.b64decode(saved[4:]))) if saved.startswith('KZ1:') else json.loads(saved)
                assert saved_data['vehicle_tier'] == 2
                reload_context = browser.new_context(viewport={'width': 390, 'height': 844}, has_touch=True, is_mobile=True, locale='ja-JP')
                reload_context.add_init_script('if(!localStorage.getItem(' + json.dumps(KEY) + '))localStorage.setItem(' + json.dumps(KEY) + ',' + json.dumps(saved) + ');')
                try:
                    restored_page = reload_context.new_page()
                    restored_page.goto(url)
                    ready(restored_page)
                    assert state(restored_page)['vehicle_tier'] == 2 and state(restored_page)['money'] == final
                    restored_page.reload()
                    ready(restored_page)
                    assert state(restored_page)['vehicle_tier'] == 2 and state(restored_page)['conserved']
                finally:
                    reload_context.close()
            else:
                data = state(page)
                assert data['bag_count'] == 1536 and len(data['bag']) == 1536
                assert data['objects']['rendered_cargo'] == 128 and data['objects']['vehicle_visible'] == 2
                page.screenshot(path='reports/player-vehicle-full-load.png')
                start = data['position']
                page.keyboard.down('ArrowUp')
                page.wait_for_function('(p) => window.kikoriState.position[1] < p[1] - 2', arg=start)
                page.keyboard.up('ArrowUp')
                page.wait_for_timeout(250)
                assert state(page)['conserved'] and state(page)['bag_count'] == 1536
                # Landscape menu still reaches the final MAX card via real scroll input.
                page.set_viewport_size({'width': 844, 'height': 390})
                page.wait_for_timeout(400)
                tap(page, 'menu')
                for _ in range(15):
                    ui = page.evaluate('window.kikoriUi')
                    if 90 < ui['vehicle']['y'] < 345:
                        break
                    page.mouse.move(420, 250)
                    page.mouse.wheel(0, 220)
                    page.wait_for_timeout(200)
                assert 90 < ui['vehicle']['y'] < 345
                page.screenshot(path='reports/player-vehicle-landscape.png')
        except Exception:
            page.screenshot(path=f'reports/player-vehicle-{scenario}-failure.png')
            print('KIKORI_PLAYER_VEHICLES_FAILED', scenario, json.dumps(state(page)), errors, flush=True)
            raise
        finally:
            context.close()
    assert screenshots[0] != screenshots[1], 'Vehicle visuals change with tier'
    assert not errors, errors
    result = {'tiers': 2, 'old_save_migration': True, 'purchase_ui': True, 'saved_reload': True, 'capacity': 1536, 'rendered_cargo_limit': 128, 'landscape': True, 'errors': errors}
    Path('reports/player-vehicles-browser.json').write_text(json.dumps(result, indent=2))
    print('KIKORI_PLAYER_VEHICLES_BROWSER', json.dumps(result), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--url')
    args = parser.parse_args()
    server = None
    if not args.url:
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory='build/web'))
        threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True, args=['--enable-webgl', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
            try:
                run(browser, args.url or f'http://127.0.0.1:{server.server_port}')
            finally:
                browser.close()
    finally:
        if server:
            server.shutdown()


if __name__ == '__main__':
    main()
