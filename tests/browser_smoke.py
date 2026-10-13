#!/usr/bin/env python3
"""Play actual WebGL export with browser input. Diagnostics are read-only.

Chromium tests real protocol touch; WebKit tests keyboard and touch taps. Engine
emulation/software rendering is not physical Android/iPhone certification.
"""
import argparse
import base64
import json
import hashlib
import struct
import zlib
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
    if page.context.browser.browser_type.name == 'webkit':
        # GTK snapshots/toDataURL can reuse an old canvas image. Capture actual
        # GPU pixels in a frame instead, keeping all framebuffer bindings intact.
        frame = page.evaluate("""() => new Promise(resolve => {
            let done=false;
            function finish(){
                if(done)return;done=true;
                const c=document.querySelector('#canvas'),g=c.getContext('webgl2');
                const previous=g.getParameter(g.READ_FRAMEBUFFER_BINDING);
                g.bindFramebuffer(g.READ_FRAMEBUFFER,null);
                const pixels=new Uint8Array(c.width*c.height*4);
                g.readPixels(0,0,c.width,c.height,g.RGBA,g.UNSIGNED_BYTE,pixels);
                g.bindFramebuffer(g.READ_FRAMEBUFFER,previous);
                let raw='';
                for(let i=0;i<pixels.length;i+=8192)raw+=String.fromCharCode(...pixels.subarray(i,i+8192));
                resolve({width:c.width,height:c.height,data:btoa(raw)});
            }
            setTimeout(finish,2500);
            requestAnimationFrame(() => requestAnimationFrame(finish));
        })""")
        width,height=frame['width'],frame['height']
        rgba=base64.b64decode(frame['data'])
        stride=width*4
        rows=b''.join(b'\0'+rgba[y*stride:(y+1)*stride] for y in reversed(range(height)))
        def chunk(kind,payload):
            return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
        data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b'')
        Path(f'reports/{name}.png').write_bytes(data)
    else:
        data = page.screenshot(path=f'reports/{name}.png')
    assert len(data)>3000, "Rendered canvas must not be an empty buffer"
    os.set_blocking(1, True)
    code = base64.b64encode(data).decode()
    for i in range(0, len(code), 2048):
        print(f'KIKORI_PREVIEW_DATA {name} ' + code[i:i + 2048], flush=True)
    return hashlib.sha256(data).hexdigest()


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
    context.add_init_script("try{localStorage.setItem('kikori.phase1.v1', JSON.stringify({money:1000000000}));}catch(e){}")
    page = context.new_page()
    page.bring_to_front()
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('console', lambda e: errors.append(e.text) if e.type == 'error' else None)
    started = time.monotonic()
    try:
        page.goto(url)
        ready(page)
        load_seconds = time.monotonic() - started
        assert state(page)['money'] == 0, 'Old idle-game wealth must not skip the new beginning'
        first_frame = capture(page, engine + '-start')
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
            if event == 'blur': page.evaluate("window.dispatchEvent(new Event('focus'))")
        # Real tab activation keeps browser/Godot rendering lifecycle coherent.
        # Overriding document.hidden can freeze WebKit's drawing while scripts run.
        page.keyboard.down('w')
        page.wait_for_timeout(150)
        background = context.new_page()
        background.goto('data:text/html,<title>Background check</title>')
        background.bring_to_front()
        page.wait_for_timeout(220)
        hidden = page.evaluate('document.hidden')
        if hidden:
            paused_elapsed = state(page)['elapsed']
            page.wait_for_timeout(400)
            assert abs(state(page)['elapsed'] - paused_elapsed) < .03
        else:
            # Headless Chromium may keep all targets visible; blur covers input reset.
            page.evaluate("window.dispatchEvent(new Event('blur'))")
        page.bring_to_front()
        background.close()
        page.wait_for_timeout(300)
        page.keyboard.up('w')
        stopped = state(page)['position']
        page.wait_for_timeout(250)
        assert math.dist(stopped, state(page)['position']) < .03
        # Keep input held while inspecting collision so automatic chopping cannot
        # remove the tested trunk during a slow browser snapshot.
        path(page, -6.3, 5.2)
        page.keyboard.down('w')
        try:
            page.wait_for_timeout(1200)
            collision = state(page)
            assert collision['trees'][0]['hp'] > 0
            assert math.dist(collision['position'], [-6.3, 3.1]) >= .74
            assert collision['position'][1] < 4.1, 'Input must push against the trunk'
        finally:
            page.keyboard.up('w')
        page.wait_for_timeout(140)
        move(page,-6.3,4.8)
        fill(page, 0)
        carry_frame = capture(page, engine + '-carry')
        assert carry_frame != first_frame, 'Rendering must update as the protagonist moves and carries logs'
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
        page.wait_for_function('window.kikoriUi.width > window.kikoriUi.height && window.kikoriState.velocity.every(v => v === 0)', timeout=10000)
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
                  'software_fps': final['fps'], 'actual_background_visibility': hidden, 'rendered_frame_changed': carry_frame != first_frame}
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


def probe(browser, url, engine):
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=True)
    page=context.new_page();page.bring_to_front();page.goto(url);ready(page)
    before=state(page)
    first=capture(page,engine+'-probe-before')
    page.keyboard.down('w');page.wait_for_timeout(900);page.keyboard.up('w');page.wait_for_timeout(300)
    after=state(page)
    second=capture(page,engine+'-probe-after')
    print('KIKORI_RENDER_PROBE',json.dumps({'before':before.get('render'),'after':after.get('render'),'position':after['position'],'renderer':page.evaluate('window.kikoriRenderer'),'changed':first!=second}),flush=True)
    assert first!=second, 'Fresh page must visibly redraw after movement'
    context.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', choices=['all', 'chromium', 'webkit'], default='all')
    parser.add_argument('--url')
    parser.add_argument('--full', action='store_true')
    parser.add_argument('--probe', action='store_true')
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
                    if args.probe:
                        probe(browser,url,engine)
                        continue
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
