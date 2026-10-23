#!/usr/bin/env python3
"""Place and tap buildings, draw roads, route three real carts and reload.
Only real browser input mutates gameplay. Native fixtures have earned revenue
and have passed the complete inventory validator before being emitted.
"""
import json, math, threading
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright
from browser_smoke import ready, state, tap, capture, path, KEY
from browser_logistics import click, select

def frames(page, count=3):
    n=state(page)['render']['process_frames']
    page.wait_for_function('(a)=>window.kikoriState.render.process_frames>=a[0]+a[1]',arg=[n,count],timeout=20000)

def project(page,x,z):
    ui=page.evaluate('window.kikoriUi');s=state(page);focus=s['render']['camera_focus'];scale=ui['height']/s['render']['camera_size']
    # Building tests stay in the level valley floor. Terrain-aware hit testing
    # in the game returns the authoritative snapped placement coordinates.
    return {'x':ui['width']/2+(x-focus[0])*scale,'y':ui['height']/2+((z-focus[2])*17.4+(focus[1]+.6)*16)/math.hypot(16,17.4)*scale}

def screen_tap(page,p):
    ui=page.evaluate('window.kikoriUi');b=page.locator('#canvas').bounding_box()
    page.touchscreen.tap(b['x']+p['x']/ui['width']*b['width'],b['y']+p['y']/ui['height']*b['height']);frames(page)

def context_with(browser,filename,errors):
    fixture=json.loads(Path('reports/'+filename+'.json').read_text())
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=True,locale='ja-JP')
    context.add_init_script('if(!localStorage.getItem('+json.dumps(KEY)+'))localStorage.setItem('+json.dumps(KEY)+','+json.dumps(json.dumps(fixture))+');')
    page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda e:errors.append(e.text) if e.type=='error' else None)
    return context,page,fixture

def run(browser,url):
    errors=[]
    context,page,fixture=context_with(browser,'production-start-fixture',errors)
    try:
        page.goto(url);ready(page)
        tap(page,'menu')
        assert all(key not in page.evaluate('window.kikoriUi') for key in ['camp','porter','mill'])
        tap(page,'close')
        for index,(kind,x,z) in enumerate([('storage',-12,9),('processor',-4,14),('factory',2,20)]):
            tap(page,'logistics');click(page,'build_'+kind)
            page.wait_for_function('(k)=>window.kikoriUi.placing===k',arg=kind)
            page.wait_for_timeout(1800);frames(page,5)
            old_money=state(page)['money'];old_position=state(page)['position'];elapsed=state(page)['elapsed']
            screen_tap(page,project(page,x,z))
            page.wait_for_function('window.kikoriUi.has_placement')
            actual=page.evaluate('window.kikoriUi.placement_at')
            assert actual==[x,z],actual
            assert len(state(page)['logistics']['sites'])==index and state(page)['money']==old_money
            assert state(page)['elapsed']==elapsed and state(page)['position']==old_position
            capture(page,'facility-'+kind+'-preview')
            tap(page,'road_confirm')
            page.wait_for_function('(n)=>window.kikoriState.logistics.sites.length===n && window.kikoriUi.site_open',arg=index+1)
            assert state(page)['money']==old_money-{'storage':180,'processor':320,'factory':600}[kind]
            if kind=='storage':tap(page,'site_worker')
            capture(page,'facility-'+kind+'-settings');tap(page,'site_close')
        # Tap the actual rendered building, then purchase a local upgrade.
        path(page,-8,9);frames(page,5)
        point=page.evaluate('window.kikoriUi.site_points.site1')
        screen_tap(page,point);page.wait_for_function('window.kikoriUi.selected_site==="site1" && window.kikoriUi.site_open')
        before=state(page)['money'];tap(page,'site_upgrade')
        page.wait_for_function('window.kikoriState.logistics.sites[0].level===2')
        assert state(page)['money']==before-324
        tap(page,'site_close');page.wait_for_timeout(3300);frames(page)
        page.reload();ready(page)
        assert len(state(page)['logistics']['sites'])==3 and state(page)['logistics']['sites'][0]['level']==2
        assert state(page)['conserved']
        # Road touch gesture is a preview, explicit confirmation charges once.
        tap(page,'logistics');click(page,'source_focus')
        page.wait_for_timeout(1800);frames(page,5)
        a=project(page,-12,9);b=project(page,-12,14)
        session=context.new_cdp_session(page)
        session.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[a]})
        session.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[b]})
        session.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
        page.wait_for_function('window.kikoriUi.road_preview_count>=5',timeout=10000)
        before=state(page)['money'];assert state(page)['logistics']['roads']==[]
        tap(page,'road_confirm');page.wait_for_function('window.kikoriState.logistics.roads.length>=5')
        assert state(page)['money']==before-len(state(page)['logistics']['roads'])*2
        session.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[a]})
        session.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[b]})
        session.send('Input.dispatchTouchEvent',{'type':'touchCancel','touchPoints':[]})
        page.wait_for_function('window.kikoriUi.road_preview_count===0')
        tap(page,'road_done')
        page.set_viewport_size({'width':844,'height':390});page.wait_for_function('window.kikoriUi.width>window.kikoriUi.height')
        # Tap after orientation change using freshly projected coordinates.
        frames(page,4);screen_tap(page,page.evaluate('window.kikoriUi.site_points.site2'))
        page.wait_for_function('window.kikoriUi.site_open && window.kikoriUi.selected_site==="site2"')
        ui=page.evaluate('window.kikoriUi');assert 0<ui['site_close']['y']<390
        capture(page,'facility-landscape');tap(page,'site_close')
    finally:context.close()
    context,page,fixture=context_with(browser,'production-route-fixture',errors)
    try:
        page.goto(url);ready(page);tap(page,'logistics')
        for i in range(3):
            select(page,'route_source',i);select(page,'route_destination',i+1)
            page.wait_for_function('(v)=>window.kikoriUi.source_id===v[0] && window.kikoriUi.destination_id===v[1]',arg=['site'+str(i+1),'market0' if i==2 else 'site'+str(i+2)])
            click(page,'cart_buy');page.wait_for_function('(n)=>window.kikoriState.logistics.carts.length===n',arg=i+1)
        tap(page,'log_close')
        baseline=fixture['sold'][0];funds=fixture['money']-360
        page.wait_for_function('(n)=>window.kikoriState.sold[0]===n+12',arg=baseline,timeout=360000)
        assert state(page)['money']==funds+480 and state(page)['conserved']
        capture(page,'facility-complete-production-chain')
        page.wait_for_timeout(3300);page.reload();ready(page)
        assert len(state(page)['logistics']['carts'])==3 and state(page)['money']==funds+480 and state(page)['conserved']
        tap(page,'logistics');click(page,'cart_pause0');tap(page,'log_close')
        page.wait_for_function('window.kikoriState.logistics.carts[0].phase==="parked"',timeout=60000)
        assert state(page)['logistics']['carts'][0]['cargo']==[]
    finally:context.close()
    # A previous release's actual loaded cart and worker inventories migrate.
    context,page,fixture=context_with(browser,'production-legacy-fixture',errors)
    try:
        page.goto(url);ready(page);assert state(page)['version']==10 and state(page)['conserved']
        page.reload();ready(page);assert state(page)['version']==10 and state(page)['conserved']
    finally:context.close()
    assert not errors,errors
    result={'free_placement':True,'tap_upgrade':True,'three_stage_transport':True,'product_income':480,'explicit_road_confirmation':True,'touch_cancel':True,'landscape':True,'save_resume':True,'conserved':True,'errors':errors}
    Path('reports/facilities-browser-results.json').write_text(json.dumps(result,indent=2))
    print('KIKORI_FACILITIES_BROWSER',json.dumps(result),flush=True)

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
