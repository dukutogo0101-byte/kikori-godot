#!/usr/bin/env python3
"""Promote vehicles and edit a three-command loop with real browser UI only."""
import argparse,json,threading
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright
from browser_smoke import ready,state,tap,capture,KEY
from browser_logistics import click as base_click,select
from browser_facilities import frames

def click(page,key):
    # Respect the same purchase debounce on fast and slow GPU hosts.
    page.wait_for_timeout(300)
    base_click(page,key)

def context_with(browser,name,errors):
    fixture=json.loads(Path('reports/'+name+'.json').read_text())
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=browser.browser_type.name=='chromium',locale='ja-JP')
    context.add_init_script('if(!localStorage.getItem('+json.dumps(KEY)+'))localStorage.setItem('+json.dumps(KEY)+','+json.dumps(json.dumps(fixture))+');')
    page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)));page.on('console',lambda e:errors.append(e.text) if e.type=='error' else None)
    return context,page,fixture

def chosen(page,source,dest,source_id,dest_id):
    select(page,'route_source',source);select(page,'route_destination',dest)
    page.wait_for_function('(v)=>window.kikoriUi.source_id===v[0] && window.kikoriUi.destination_id===v[1]',arg=[source_id,dest_id])

def run(browser,url):
    errors=[];engine=browser.browser_type.name
    context,page,fixture=context_with(browser,'transport-ui-fixture',errors)
    try:
        page.goto(url);ready(page);tap(page,'logistics')
        assert state(page)['version']==8 and page.evaluate('window.kikoriUi.cart_limit')==6
        before=state(page)['money']
        click(page,'cart_upgrade0');page.wait_for_function('window.kikoriState.logistics.carts[0].tier===1')
        assert state(page)['money']==before-6000 and state(page)['logistics']['carts'][0]['level']==1
        capture(page,engine+'-transport-horse-upgrade')
        tap(page,'log_close');frames(page,4);capture(page,engine+'-transport-horse-world')
        # Vehicle is parked: configuration and promotion do not move any cargo.
        tap(page,'logistics')
        for level,cost in [(2,1800),(3,3600),(4,7200),(5,14400)]:
            before=state(page)['money'];click(page,'cart_upgrade0')
            page.wait_for_function('(n)=>window.kikoriState.logistics.carts[0].level===n',arg=level)
            assert state(page)['money']==before-cost
        before=state(page)['money'];click(page,'cart_upgrade0')
        page.wait_for_function('window.kikoriState.logistics.carts[0].tier===2 && window.kikoriState.logistics.carts[0].level===1')
        assert state(page)['money']==before-80000
        # Retain first route, append B -> C, then independent D -> base.
        chosen(page,1,2,'site2','site3');click(page,'cart_append0')
        page.wait_for_function('window.kikoriState.logistics.carts[0].orders.length===2')
        chosen(page,3,4,'site4','market0');click(page,'cart_append0')
        page.wait_for_function('window.kikoriState.logistics.carts[0].orders.length===3')
        cart=state(page)['logistics']['carts'][0]
        assert cart['orders']==[{'source':'site1','destination':'site2'},{'source':'site2','destination':'site3'},{'source':'site4','destination':'market0'}]
        assert cart['phase']=='parked' and cart['pause_requested']
        # Delete and re-add one command; other commands remain intact.
        click(page,'cart_remove0_1');page.wait_for_function('window.kikoriState.logistics.carts[0].orders.length===2')
        chosen(page,1,2,'site2','site3');click(page,'cart_order0_1')
        page.wait_for_function('window.kikoriState.logistics.carts[0].orders[1].source==="site2"')
        chosen(page,3,4,'site4','market0');click(page,'cart_append0')
        page.wait_for_function('window.kikoriState.logistics.carts[0].orders.length===3')
        capture(page,engine+'-transport-three-orders')
        # Fill current building limit using purchased, actually configured carts.
        chosen(page,0,4,'site1','market0')
        for count in range(2,7):
            click(page,'cart_buy');page.wait_for_function('(n)=>window.kikoriState.logistics.carts.length===n',arg=count)
        before=state(page)['money'];click(page,'cart_buy');frames(page)
        assert len(state(page)['logistics']['carts'])==6 and state(page)['money']==before
        tap(page,'log_close');page.wait_for_timeout(3300);page.reload();ready(page)
        cart=state(page)['logistics']['carts'][0]
        assert cart['tier']==2 and len(cart['orders'])==3 and cart['pause_requested'] and state(page)['conserved']
        capture(page,engine+'-transport-truck-world')
        # A deliberately isolated command fixture has one vehicle, keeping actual
        # cycle assertions independent of the extra fleet purchased above.
    except Exception:
        print('KIKORI_TRANSPORT_FAILED',json.dumps({'ui':page.evaluate('window.kikoriUi'),'errors':errors}),flush=True)
        capture(page,engine+'-transport-failure');raise
    finally:context.close()
    context,page,fixture=context_with(browser,'transport-orders-fixture',errors)
    try:
        page.goto(url);ready(page);tap(page,'logistics');click(page,'cart_pause0');tap(page,'log_close')
        baseline=fixture['money'];seen=set()
        for _ in range(300):
            current=state(page);cart=current['logistics']['carts'][0];seen.add(cart['order_index'])
            if current['money']==baseline+240 and cart['order_index']==0:break
            page.wait_for_timeout(1000)
        assert state(page)['money']==baseline+240 and seen=={0,1,2} and state(page)['conserved'],{'money':state(page)['money'],'seen':list(seen)}
        # Pause safely, reload, and resume the retained command cycle.
        tap(page,'logistics');click(page,'cart_pause0');tap(page,'log_close')
        page.wait_for_function('window.kikoriState.logistics.carts[0].phase==="parked"',timeout=60000)
        page.wait_for_timeout(3300);saved=state(page)['logistics']['carts'][0];page.reload();ready(page)
        cart=state(page)['logistics']['carts'][0]
        assert cart['orders']==saved['orders'] and cart['order_index']==saved['order_index'] and cart['cargo']==[]
    finally:context.close()
    context,page,fixture=context_with(browser,'transport-v7-fixture',errors)
    try:
        page.goto(url);ready(page)
        assert state(page)['version']==8 and state(page)['conserved']
        assert all(c['tier']==0 and len(c['orders'])==1 for c in state(page)['logistics']['carts'])
        page.wait_for_timeout(3300);page.reload();ready(page);assert state(page)['version']==8 and state(page)['conserved']
    finally:context.close()
    context,page,fixture=context_with(browser,'transport-truck-loaded-fixture',errors)
    try:
        page.goto(url);ready(page);frames(page,3)
        # Full logical cargo can start unloading before ready; assert conservation
        # and successful rendering without ever creating 2,048 mesh instances.
        assert state(page)['conserved'];capture(page,engine+'-transport-loaded-truck')
    finally:context.close()
    assert not errors,errors
    result={'engine':engine,'five_levels_per_vehicle':True,'horse_and_truck_promotions':True,'three_order_editing':True,'cyclic_delivery':True,'building_vehicle_limit':True,'pause_and_save_resume':True,'v7_migration':True,'large_cargo_rendering':True,'errors':errors}
    Path('reports/transport-'+engine+'.json').write_text(json.dumps(result,indent=2));print('KIKORI_TRANSPORT_BROWSER',json.dumps(result),flush=True)

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
