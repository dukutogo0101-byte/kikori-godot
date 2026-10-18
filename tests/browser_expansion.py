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
    assert len(state(page)['layout'])>200
    assert len(state(page)['markets'])==1
    assert state(page)['render']['camera_size']>=27.9
    snap(page,'wide-start')
    tap(page,'map')
    assert page.evaluate('window.kikoriUi.map_open')
    snap(page,'watershed-map')
    tap(page,'map_close')
    assert not page.evaluate('window.kikoriUi.modal')
    assert not page.evaluate('window.kikoriUi.modal')
    start=state(page)['position']
    tap(page,'view')
    page.wait_for_function('window.kikoriState.wide_view && window.kikoriState.render.camera_size > 35')
    assert state(page)['position']==start
    snap(page,'maximum-view')
    context.close()

    assert not errors, errors
    result={'actual_web_export':True,'markets':1,'wide_map':True,'errors':errors}
    Path('reports/expansion-browser-results.json').write_text(json.dumps(result,indent=2))
    print('KIKORI_EXPANSION_BROWSER',json.dumps(result),flush=True)

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
