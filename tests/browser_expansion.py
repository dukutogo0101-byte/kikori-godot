#!/usr/bin/env python3
"""Verify expansion UI and active-play automation on an actual Web export.

The equipment scenario loads a validated earned-revenue fixture from native
checks; browser controls perform purchases, movement and reload. No game debug
mutation API is used. This is separate from the fresh-save direct-loop test.
"""
import json
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_smoke import ready, state, tap, path, KEY

def snap(page,name):
    page.screenshot(path=f'reports/expansion-{name}.png')

def visible_tap(page,key):
    for _ in range(12):
        ui=page.evaluate('window.kikoriUi')
        y=ui[key]['y']
        if 165<y<710:
            tap(page,key)
            return
        page.mouse.move(185,530)
        page.mouse.wheel(0,260 if y>=710 else -260)
        page.wait_for_timeout(400)
    raise AssertionError(f'Cannot scroll to {key}: {ui[key]}')

def run(browser,url):
    errors=[]
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=True,locale='ja-JP')
    page=context.new_page()
    page.on('pageerror',lambda e: errors.append(str(e)))
    page.on('console',lambda e: errors.append(e.text) if e.type=='error' else None)
    page.goto(url);ready(page)
    page.wait_for_timeout(600)
    assert len(state(page)['layout'])==69
    assert len(state(page)['markets'])==4
    assert state(page)['render']['camera_size']>=27.9
    snap(page,'wide-start')
    start=state(page)['position']
    tap(page,'view')
    page.wait_for_function('window.kikoriState.wide_view && window.kikoriState.render.camera_size > 35')
    assert state(page)['position']==start
    snap(page,'maximum-view')
    context.close()

    fixture=json.loads(Path('reports/automation-fixture.json').read_text())
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=True,locale='ja-JP')
    # Seed only once; later reloads must use the game's own autosave.
    context.add_init_script('if (!localStorage.getItem('+json.dumps(KEY)+')) localStorage.setItem('+json.dumps(KEY)+','+json.dumps(json.dumps(fixture))+');')
    page=context.new_page()
    page.on('pageerror',lambda e: errors.append(str(e)))
    page.on('console',lambda e: errors.append(e.text) if e.type=='error' else None)
    page.goto(url);ready(page)
    assert state(page)['money']==fixture['money']
    tap(page,'menu')
    snap(page,'equipment')
    for key in ['camp','porter','mill']:
        before=state(page)['money']
        visible_tap(page,key)
        page.wait_for_function('(k) => window.kikoriState.automation.levels[0][k]===1',arg=key)
        assert state(page)['money']==before-{'camp':180,'porter':140,'mill':320}[key]
    snap(page,'automation-menu')
    # The header close button remains visible even after scrolling to facilities.
    tap(page,'close')
    assert not page.evaluate('window.kikoriUi.modal')
    path(page,-8.3,9)
    page.wait_for_function('window.kikoriState.sold[0] > '+str(fixture['sold'][0]),timeout=90000)
    assert state(page)['conserved']
    snap(page,'working-camp')
    page.reload();ready(page)
    assert state(page)['automation']['levels'][0]=={'camp':1,'porter':1,'mill':1}
    assert state(page)['conserved']
    assert state(page)['money']>=fixture['money']-640
    page.keyboard.down('s')
    page.set_viewport_size({'width':844,'height':390})
    page.wait_for_function('window.kikoriUi.width > window.kikoriUi.height && window.kikoriState.velocity.every(v => v === 0)',timeout=10000)
    stopped=state(page)['position']
    page.wait_for_timeout(500)
    assert state(page)['position']==stopped
    page.keyboard.up('s')
    snap(page,'landscape')
    tap(page,'menu')
    # Check scrollable facility UI and persistent close in the shallow viewport.
    page.mouse.move(420,230);page.mouse.wheel(0,500);page.wait_for_timeout(500)
    tap(page,'close')
    assert not page.evaluate('window.kikoriUi.modal')
    assert not errors,errors
    result={'actual_web_export':True,'fixture':'validated earned revenue for equipment scenario','markets':4,'trees':69,'purchases':state(page)['automation']['levels'][0],'conserved':state(page)['conserved'],'errors':errors,'software_fps':state(page)['fps']}
    Path('reports/expansion-browser-results.json').write_text(json.dumps(result,indent=2))
    print('KIKORI_EXPANSION_BROWSER',json.dumps(result),flush=True)
    context.close()

def main():
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/web'))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
            try: run(browser,f'http://127.0.0.1:{server.server_port}')
            finally: browser.close()
    finally: server.shutdown()
if __name__=='__main__':main()
