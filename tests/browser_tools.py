#!/usr/bin/env python3
"""Exercise replacement upgrades, visible tool tiers and 128-log cargo by real UI."""
import json
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_smoke import ready, state, tap, capture, move, KEY
from browser_expansion import visible_tap

def run(browser, url):
    errors = []
    for loaded in [False, True]:
        fixture = json.loads(Path('reports/tools-loaded-fixture.json' if loaded else 'reports/tools-fixture.json').read_text())
        context = browser.new_context(viewport={'width':390,'height':844},is_mobile=True,has_touch=True,locale='ja-JP')
        context.add_init_script('if(!localStorage.getItem('+json.dumps(KEY)+'))localStorage.setItem('+json.dumps(KEY)+','+json.dumps(json.dumps(fixture))+');')
        page = context.new_page()
        page.on('pageerror',lambda error:errors.append(str(error)))
        page.on('console',lambda message:errors.append(message.text) if message.type=='error' else None)
        try:
            page.goto(url);ready(page)
            assert state(page)['speed']==6.5 and state(page)['capacity']==128
            assert 'pack' not in state(page)['levels'] and 'boots' not in state(page)['levels']
            if loaded:
                assert len(state(page)['bag'])==128 and state(page)['objects']['rendered_cargo']==128
                capture(page,'chromium-128-log-bundle')
                move(page,0,10)
                capture(page,'chromium-128-logs-walking')
                saved=state(page)['bag']
                page.evaluate("window.dispatchEvent(new Event('blur'))")
                page.reload();ready(page)
                assert state(page)['bag']==saved and state(page)['conserved']
                assert state(page)['objects']['rendered_cargo']==128
            else:
                tap(page,'menu')
                for level in range(1,3):
                    page.wait_for_timeout(400)
                    tap(page,'cut_range')
                    page.wait_for_function('(n)=>window.kikoriState.levels.cut_range===n',arg=level)
                capture(page,'chromium-long-axe-menu')
                tap(page,'close')
                page.wait_for_function('window.kikoriState.trees[5].hp<3 && window.kikoriState.trees[6].hp<3',timeout=10000)
                assert len(state(page)['targets'])>=2
                capture(page,'chromium-multiple-tree-cut')
                page.wait_for_function('window.kikoriState.created[0]>=3006',timeout=10000)
                assert state(page)['ground'] and not state(page)['bag']
                tap(page,'menu');page.wait_for_timeout(400);tap(page,'collect_range')
                page.wait_for_function('window.kikoriState.levels.collect_range===1')
                page.wait_for_timeout(400);tap(page,'collect_range')
                page.wait_for_function('window.kikoriState.levels.collect_range===2')
                tap(page,'close')
                page.wait_for_function('window.kikoriState.bag.length>0',timeout=10000)
                assert state(page)['conserved']
                for level in range(3,7):
                    tap(page,'menu');page.wait_for_timeout(400);tap(page,'cut_range')
                    page.wait_for_function('(n)=>window.kikoriState.levels.cut_range===n',arg=level)
                    tap(page,'close');page.wait_for_timeout(400)
                    assert state(page)['objects']['tool_tier']==(2 if level<5 else 3)
                    capture(page,'chromium-tool-level-'+str(level))
                tap(page,'menu')
                visible_tap(page,'install')
                page.wait_for_function("document.querySelector('#app-dialog').open && window.kikoriState.paused")
                elapsed=state(page)['elapsed']
                page.wait_for_timeout(500)
                assert state(page)['elapsed']==elapsed,'Web install dialog pauses gameplay'
                assert 'Chrome' in page.locator('#app-description').inner_text() or not page.locator('#app-install').is_hidden()
                page.locator('#app-close').click()
                assert not page.locator('#app-dialog').evaluate('(d)=>d.open')
                tap(page,'close')
                page.wait_for_function('!window.kikoriState.paused')
                assert state(page)['conserved']
        except Exception:
            print('KIKORI_TOOLS_FAILED',json.dumps(state(page)),errors,flush=True)
            capture(page,'chromium-tools-failure')
            raise
        finally:context.close()
    assert not errors,errors
    result={'standard_speed':6.5,'capacity':128,'rendered_logs':128,'multi_cut':True,'tool_tiers':4,'install_entry':True,'errors':errors}
    Path('reports/tools-browser-results.json').write_text(json.dumps(result,indent=2))
    print('KIKORI_TOOLS_BROWSER',json.dumps(result),flush=True)

def main():
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/web'))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
            try:run(browser,f'http://127.0.0.1:{server.server_port}')
            finally:browser.close()
    finally:server.shutdown()
if __name__=='__main__':main()
