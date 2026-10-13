#!/usr/bin/env python3
"""Play actual WebGL export with browser input. Diagnostics are read-only.

Chromium tests real protocol touch; WebKit tests keyboard and touch taps. Engine
emulation/software rendering is not physical Android/iPhone certification.
"""
import argparse
import base64
import json
import math
import os
import threading
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from playwright.sync_api import sync_playwright

KEY = 'kikori.adventure.v2'


def capture(page, name):
    data = page.screenshot(path=f'reports/{name}.png')
    os.set_blocking(1, True)
    code = base64.b64encode(data).decode()
    for i in range(0, len(code), 2048):
        print(f'KIKORI_PREVIEW_DATA {name} ' + code[i:i + 2048], flush=True)


def state(page):
    return page.evaluate('window.kikoriState')


def ready(page):
    page.wait_for_function('window.kikoriReady && window.kikoriState', timeout=90000)
    page.wait_for_timeout(250)


def tap(page, key):
    ui = page.evaluate('window.kikoriUi')
    bounds = page.locator('#canvas').bounding_box()
    point = ui[key]
    page.touchscreen.tap(bounds['x'] + point['x'] / ui['width'] * bounds['width'],
                         bounds['y'] + point['y'] / ui['height'] * bounds['height'])
    page.wait_for_timeout(160)


def move(page, x, z):
    # Coarse keyboard movement, then actual analog mouse input near the target.
    # Software WebGL may update diagnostics in large batches; avoid oscillating
    # between opposite keys based on a stale position.
    start = time.monotonic()
    held = set()
    try:
        while time.monotonic() - start < 45:
            p = state(page)['position']
            dx, dz = x - p[0], z - p[1]
            if abs(dx) < .28 and abs(dz) < .28:
                return
            if max(abs(dx), abs(dz)) <= 1.1:
                for key in held:
                    page.keyboard.up(key)
                held.clear()
                page.wait_for_timeout(220)
                p = state(page)['position']
                dx, dz = x - p[0], z - p[1]
                distance = math.hypot(dx, dz)
                if abs(dx) < .28 and abs(dz) < .28:
                    return
                strength = min(.6, max(.16, distance * .42))
                page.mouse.move(260, 540)
                page.mouse.down()
                page.mouse.move(260 + dx / distance * 64 * strength,
                                540 + dz / distance * 64 * strength)
                page.wait_for_timeout(240)
                page.mouse.up()
                page.wait_for_timeout(220)
                continue
            wanted = set()
            if abs(dx) > .24:
                wanted.add('d' if dx > 0 else 'a')
            if abs(dz) > .24:
                wanted.add('s' if dz > 0 else 'w')
            for key in held - wanted:
                page.keyboard.up(key)
            for key in wanted - held:
                page.keyboard.down(key)
            held = wanted
            page.wait_for_timeout(90)
        raise AssertionError(f'Movement stuck at {state(page)["position"]} toward {(x, z)}')
    finally:
        for key in held:
            page.keyboard.up(key)
        page.wait_for_timeout(160)


def path(page, x, z):
    move(page, 0, state(page)['position'][1])
    move(page, 0, z)
    move(page, x, z)


def harvest(page, kind):
    for attempt in range(50):
        s = state(page)
        if len(s['bag']) >= s['capacity']:
            return
        candidates = [i for i, t in enumerate(s['trees'])
                      if t['hp'] > 0 and s['layout'][i]['kind'] == kind
                      and abs(s['layout'][i]['position'][0]) < 4]
        if not candidates:
            page.wait_for_timeout(1000)
            continue
        index = min(candidates, key=lambda i: math.dist(s['layout'][i]['position'], s['position']))
        x, z = s['layout'][index]['position']
        path(page, x - math.copysign(.95, x), z)
        page.wait_for_function('(i) => window.kikoriState.trees[i].hp === 0 || '
                               'window.kikoriState.bag.length >= window.kikoriState.capacity',
                               arg=index, timeout=20000)
        if state(page)['trees'][index]['hp'] == 0:
            move(page, x, z)
        return
    raise AssertionError('No reachable regenerated tree')


def fill(page, kind):
    for _ in range(30):
        s = state(page)
        if len(s['bag']) >= s['capacity']:
            return
        harvest(page, kind)
    raise AssertionError('Unable to fill pack')


def sell(page):
    before = state(page)
    expected = sum([10, 24, 50][log['kind']] for log in before['bag'])
    path(page, 4, 9)
    page.wait_for_function('window.kikoriState.bag.length === 0', timeout=10000)
    after = state(page)
    assert after['money'] == before['money'] + expected, 'Each sold log pays exactly once'
    assert after['conserved']


def buy(page, key):
    tap(page, 'menu')
    before = state(page)
    assert before['money'] >= before['prices'][key]
    tap(page, key)
    page.wait_for_function('(k) => window.kikoriState.levels[k] === 1', arg=key, timeout=5000)
    after = state(page)
    assert after['money'] == before['money'] - before['prices'][key]
    capture(page, page.context.browser.browser_type.name + '-upgrade-' + key)
    tap(page, 'close')


def touch_checks(page, context):
    protocol = context.new_cdp_session(page)
    def touch(kind, points):
        protocol.send('Input.dispatchTouchEvent', {'type': kind, 'touchPoints': points})
    start = state(page)['position']
    touch('touchStart', [{'x': 190, 'y': 550}])
    touch('touchMove', [{'x': 130, 'y': 510}])
    page.wait_for_timeout(450)
    touch('touchEnd', [])
    page.wait_for_timeout(250)
    stopped = state(page)['position']
    assert math.dist(start, stopped) > .35, 'Protocol touch drag must move hero'
    page.wait_for_timeout(250)
    assert math.dist(stopped, state(page)['position']) < .03, 'Release stops immediately'
    touch('touchStart', [{'x': 190, 'y': 550}])
    touch('touchMove', [{'x': 250, 'y': 550}])
    page.wait_for_timeout(200)
    touch('touchCancel', [])
    page.wait_for_timeout(250)
    stopped = state(page)['position']
    page.wait_for_timeout(250)
    assert math.dist(stopped, state(page)['position']) < .03, 'Cancellation clears drag'
    protocol.detach()


def inspect(browser, url, engine, full):
    context = browser.new_context(viewport={'width': 390, 'height': 844}, is_mobile=True,
                                  has_touch=True, locale='ja-JP')
    context.add_init_script("localStorage.setItem('kikori.phase1.v1', JSON.stringify({money:1000000000}));")
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda e: errors.append(e.text) if e.type == 'error' else None)
    started = time.monotonic()
    try:
        page.goto(url)
        ready(page)
        load_seconds = time.monotonic() - started
        assert state(page)['money'] == 0, 'Old idle-game wealth must not skip the new beginning'
        capture(page, engine + '-start')
        if engine == 'chromium':
            touch_checks(page, context)
        # Tapping UI and opening a modal must never create movement.
        stopped = state(page)['position']
        tap(page, 'menu')
        assert page.evaluate('window.kikoriUi.modal')
        page.keyboard.down('w')
        page.wait_for_timeout(250)
        page.keyboard.up('w')
        assert math.dist(stopped, state(page)['position']) < .03
        tap(page, 'close')
        # Blur, orientation change and visibility events clear held keyboard input.
        for event in ['blur', 'orientationchange']:
            page.keyboard.down('w')
            page.wait_for_timeout(150)
            page.evaluate('(event) => window.dispatchEvent(new Event(event))', event)
            page.wait_for_timeout(220)
            stopped = state(page)['position']
            page.wait_for_timeout(220)
            assert math.dist(stopped, state(page)['position']) < .03, event + ' must reset input'
            page.keyboard.up('w')
        page.evaluate("Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'))")
        page.wait_for_timeout(200)
        paused = state(page)
        page.wait_for_timeout(400)
        assert state(page)['paused'] and abs(state(page)['elapsed'] - paused['elapsed']) < .03
        page.evaluate("delete document.hidden;document.dispatchEvent(new Event('visibilitychange'))")
        page.wait_for_timeout(200)
        # Observe physical trunk collision through actual keys.
        path(page, 2.45, 3.1)
        page.keyboard.down('d')
        page.wait_for_timeout(500)
        page.keyboard.up('d')
        page.wait_for_timeout(140)
        assert math.dist(state(page)['position'], [3.4, 3.1]) >= .74
        fill(page, 0)
        capture(page, engine + '-carry')
        sell(page)
        sale_seconds = time.monotonic() - started
        capture(page, engine + '-sale')
        buy(page, 'pack')
        assert state(page)['capacity'] == 10
        capture(page, engine + '-upgrades')
        saved = page.evaluate('(key) => JSON.parse(localStorage.getItem(key))', KEY)
        page.reload()
        ready(page)
        assert state(page)['levels']['pack'] == 1 and state(page)['money'] == saved['money']
        assert state(page)['projects'] == saved['projects']
        if full:
            fill(page, 0); sell(page); buy(page, 'axe')
            fill(page, 0); sell(page); buy(page, 'boots')
            # The bridge physically blocks the route before its completion.
            path(page, 0, -6.5)
            page.keyboard.down('w'); page.wait_for_timeout(900); page.keyboard.up('w')
            page.wait_for_timeout(160)
            assert state(page)['position'][1] > -6.8
            capture(page, engine + '-bridge-before')
            fill(page, 0)
            path(page, 0, -5.1)
            page.wait_for_function('window.kikoriState.projects.bridge >= 3', timeout=5000)
            move(page, 0, -3.1)
            page.wait_for_timeout(3200)
            partial = state(page)['projects']['bridge']
            assert 0 < partial < 60
            page.reload(); ready(page)
            assert state(page)['projects']['bridge'] == partial
            for _ in range(15):
                if state(page)['projects']['bridge'] == 60:
                    break
                fill(page, 0)
                path(page, 0, -5.1)
                page.wait_for_function('window.kikoriState.bag.length === 0 || window.kikoriState.projects.bridge === 60', timeout=10000)
                assert state(page)['conserved']
            assert state(page)['projects']['bridge'] == 60
            capture(page, engine + '-bridge-open')
            path(page, 0, -12.8)
            harvest(page, 1)
            assert any(log['kind'] == 1 for log in state(page)['bag'])
            capture(page, engine + '-amber-forest')
            sell(page)
            page.reload(); ready(page)
            assert state(page)['projects']['bridge'] == 60
            assert state(page)['levels'] == {'axe': 1, 'pack': 1, 'boots': 1}
        final = state(page)
        # Wide controls must remain usable; resizing cannot leave a held input.
        page.keyboard.down('s')
        page.set_viewport_size({'width': 844, 'height': 390})
        page.wait_for_timeout(300)
        stopped = state(page)['position']
        page.wait_for_timeout(250)
        assert math.dist(stopped, state(page)['position']) < .03
        page.keyboard.up('s')
        assert page.evaluate('window.kikoriUi.width > window.kikoriUi.height'), 'Landscape must fill the window'
        capture(page, engine + '-landscape')
        tap(page, 'menu'); tap(page, 'close')
        # A broken new-format save fails safely; old-format state is also rejected.
        for raw in ['{invalid json', json.dumps({'version': 1, 'money': 1000000})]:
            # Inject after the old document's focus/unload autosave has finished.
            page.add_init_script('localStorage.setItem(' + json.dumps(KEY) + ',' + json.dumps(raw) + ');')
            page.reload(); ready(page)
            assert state(page)['money'] == 0 and state(page)['projects']['bridge'] == 0
        assert page.evaluate("document.querySelector('#canvas').getContext('webgl2').getError()") == 0
        assert not errors, errors
        result = {'engine': engine, 'full_route': full, 'load_seconds': round(load_seconds, 2),
                  'first_sale_wall_seconds': round(sale_seconds, 2), 'timings': final['timings'],
                  'money': final['money'], 'levels': final['levels'], 'projects': final['projects'],
                  'objects': final['objects'], 'conserved': final['conserved'], 'errors': errors,
                  'software_fps': final['fps']}
        # Separate context verifies blocked storage without damaging successful saves.
        restricted = browser.new_context(viewport={'width': 390, 'height': 844})
        restricted.add_init_script("Storage.prototype.getItem=function(){throw new Error('denied')};Storage.prototype.setItem=function(){throw new Error('denied')};")
        blocked = restricted.new_page(); blocked.goto(url); ready(blocked)
        assert not state(blocked)['saved'] and state(blocked)['money'] == 0
        blocked.keyboard.down('w'); blocked.wait_for_timeout(300); blocked.keyboard.up('w'); blocked.wait_for_timeout(220)
        assert state(blocked)['position'][1] < 10
        restricted.close()
        return result
    except Exception:
        print('KIKORI_FAILED_STATE', json.dumps(state(page)), 'ERRORS', errors, flush=True)
        capture(page, engine + '-failure')
        raise
    finally:
        context.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', choices=['all', 'chromium', 'webkit'], default='all')
    parser.add_argument('--url')
    parser.add_argument('--full', action='store_true')
    args = parser.parse_args()
    Path('reports').mkdir(exist_ok=True)
    server = None
    url = args.url
    if not url:
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(SimpleHTTPRequestHandler, directory='build/web'))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        url = f'http://127.0.0.1:{server.server_port}'
    try:
        with sync_playwright() as p:
            for engine in (['chromium', 'webkit'] if args.engine == 'all' else [args.engine]):
                opts = {'headless': engine != 'webkit'}
                if engine == 'chromium':
                    opts['args'] = ['--enable-webgl', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']
                browser = getattr(p, engine).launch(**opts)
                try:
                    result = inspect(browser, url, engine, args.full)
                    Path(f'reports/{engine}-results.json').write_text(json.dumps(result, indent=2))
                    print('KIKORI_BROWSER_RESULT', json.dumps(result), flush=True)
                finally:
                    browser.close()
    finally:
        if server:
            server.shutdown()

if __name__ == '__main__':
    main()
