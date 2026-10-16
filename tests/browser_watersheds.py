#!/usr/bin/env python3
"""Inspect the far, elevated map through the actual Web renderer and controls."""
import json, threading
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright
from browser_smoke import KEY, ready, state, tap, capture

def run(browser,url):
    fixture=json.loads(Path('reports/watersheds-fixture.json').read_text())
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=True,locale='ja-JP')
    context.add_init_script('if(!localStorage.getItem('+json.dumps(KEY)+'))localStorage.setItem('+json.dumps(KEY)+','+json.dumps(json.dumps(fixture))+');')
    page=context.new_page();errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda e:errors.append(e.text) if e.type=='error' else None)
    try:
        page.goto(url);ready(page)
        initial=state(page)
        assert initial['position']==fixture['position'] and initial['projects']['high_bridge']==120
        assert initial['render']['hero_height']>.5 and len(initial['markets'])==1
        capture(page,'highland-terrain')
        tap(page,'map');assert page.evaluate('window.kikoriUi.map_open')
        before=state(page)['elapsed']
        page.keyboard.down('w');page.wait_for_timeout(300);page.keyboard.up('w')
        assert state(page)['elapsed']==before and state(page)['position']==initial['position']
        capture(page,'highland-whole-map')
        tap(page,'map_close')
        # Changing orientation keeps the map, its close button and controls usable.
        page.set_viewport_size({'width':844,'height':390})
        page.wait_for_function('window.kikoriUi.width > window.kikoriUi.height')
        tap(page,'map');capture(page,'highland-map-landscape');tap(page,'map_close')
        assert not page.evaluate('window.kikoriUi.modal')
        page.reload();ready(page)
        assert state(page)['position']==fixture['position'] and state(page)['conserved']
        assert not errors,errors
        result={'far_elevated_terrain':True,'single_terminal':True,'map_pauses_game':True,'map_both_orientations':True,'conserved':True,'errors':errors}
        Path('reports/watersheds-browser-results.json').write_text(json.dumps(result,indent=2))
        print('KIKORI_WATERSHEDS_BROWSER',json.dumps(result),flush=True)
    finally: context.close()

def main():
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/web'))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
            try:run(browser,f'http://127.0.0.1:{server.server_port}')
            finally:browser.close()
    finally: server.shutdown()
if __name__=='__main__':main()
