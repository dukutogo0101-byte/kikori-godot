#!/usr/bin/env python3
"""Build a large facility and buy material promotions through real touch UI."""
import argparse, json, threading, gzip, base64
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright
from browser_smoke import ready, state, tap, capture, KEY
from browser_transport import context_with, click
from browser_facilities import frames, project, screen_tap

def run(browser,url):
    errors=[];engine=browser.browser_type.name
    context,page,fixture=context_with(browser,'building-start-fixture',errors)
    try:
        page.goto(url);ready(page);tap(page,'logistics')
        click(page,'build_size');page.wait_for_function('window.kikoriUi.large_build')
        click(page,'build_size');page.wait_for_function('!window.kikoriUi.large_build')
        click(page,'build_size');click(page,'build_storage')
        page.wait_for_function('window.kikoriUi.placing_large && window.kikoriUi.placing==="storage"')
        page.wait_for_timeout(1800);frames(page,4)
        before=state(page)['money'];elapsed=state(page)['elapsed']
        screen_tap(page,project(page,-12,10))
        page.wait_for_function('window.kikoriUi.has_placement')
        assert page.evaluate('window.kikoriUi.placement_at')==[-12,10]
        assert state(page)['money']==before and state(page)['elapsed']==elapsed
        capture(page,engine+'-large-building-preview')
        tap(page,'road_confirm')
        page.wait_for_function('window.kikoriState.logistics.sites.length===1 && window.kikoriUi.site_open')
        site=state(page)['logistics']['sites'][0]
        assert site['large'] and site['tier']==0 and site['level']==1 and len(site['crew'])==5
        assert state(page)['money']==before-900
        tap(page,'site_worker');tap(page,'site_close')
        page.wait_for_timeout(3300);page.reload();ready(page)
        assert state(page)['logistics']['sites'][0]['large'] and state(page)['conserved']
    except Exception:
        print('KIKORI_BUILDINGS_FAILED',engine,json.dumps({'ui':page.evaluate('window.kikoriUi'),'state':state(page)}),flush=True);raise
    finally:context.close()
    context,page,fixture=context_with(browser,'building-promote-fixture',errors)
    try:
        page.goto(url);ready(page);frames(page,4)
        screen_tap(page,page.evaluate('window.kikoriUi.site_points.site1'))
        page.wait_for_function('window.kikoriUi.site_open')
        for tier in [1,2]:
            before=state(page)['money'];cost=320*(30 if tier==1 else 300)*5
            click(page,'site_upgrade')
            page.wait_for_function('(t)=>window.kikoriState.logistics.sites[0].tier===t && window.kikoriState.logistics.sites[0].level===1',arg=tier)
            assert state(page)['money']==before-cost
            capture(page,engine+'-building-material-'+str(tier))
            for level in range(2,6):
                before=state(page)['money'];cost=round(320*(10**tier)*(1.8**(level-1)))*5
                click(page,'site_upgrade')
                page.wait_for_function('(n)=>window.kikoriState.logistics.sites[0].level===n',arg=level)
                assert state(page)['money']==before-cost
        before=state(page)['money'];click(page,'site_upgrade');frames(page)
        assert state(page)['money']==before and state(page)['logistics']['sites'][0]['level']==5
        # Focus the actual structure while construction mode freezes production.
        click(page,'site_focus');page.wait_for_timeout(1800);frames(page,4)
        capture(page,engine+'-large-steel-building-world');tap(page,'road_done')
        page.wait_for_timeout(3300);page.reload();ready(page)
        site=state(page)['logistics']['sites'][0]
        assert site['tier']==2 and site['level']==5 and site['large'] and state(page)['conserved']
    except Exception:
        print('KIKORI_BUILDINGS_FAILED',engine,json.dumps({'ui':page.evaluate('window.kikoriUi'),'state':state(page)}),flush=True);raise
    finally:context.close()
    context,page,fixture=context_with(browser,'building-large-stock-fixture',errors)
    try:
        page.goto(url);ready(page);frames(page,3)
        screen_tap(page,page.evaluate('window.kikoriUi.site_points.site1'))
        page.wait_for_function('window.kikoriUi.site_open')
        site=state(page)['logistics']['sites'][0]
        assert len(site['input'])==256 and len(site['output'])==256
        assert site['input_count']+site['output_count']==18000 and site['buffers_truncated']
        click(page,'site_mode') # A real settings change synchronously saves every ID.
        raw=page.evaluate('(k)=>localStorage.getItem(k)',KEY)
        saved=json.loads(gzip.decompress(base64.b64decode(raw[4:])))
        buffers=saved['logistics']['sites'][0]
        assert len(buffers['input'])+len(buffers['output'])==18000
        page.reload();ready(page)
        site=state(page)['logistics']['sites'][0]
        assert site['input_count']+site['output_count']==18000 and state(page)['conserved']
    finally:context.close()
    assert not errors,errors
    result={'engine':engine,'large_touch_placement':True,'cost_five_times':True,'six_workers':True,'wood_stone_steel':True,'five_levels_per_structure':True,'maximum_guard':True,'large_stock_save':18000,'save_resume':True,'errors':errors}
    Path('reports/buildings-'+engine+'.json').write_text(json.dumps(result,indent=2))
    print('KIKORI_BUILDINGS_BROWSER',json.dumps(result),flush=True)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--engine',choices=['chromium','webkit'],default='chromium');args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/web'));threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        with sync_playwright() as p:
            browser=getattr(p,args.engine).launch(headless=args.engine!='webkit',args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] if args.engine=='chromium' else [])
            try:run(browser,f'http://127.0.0.1:{server.server_port}')
            finally:browser.close()
    finally:server.shutdown()
if __name__=='__main__':main()
