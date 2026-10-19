#!/usr/bin/env python3
"""Edit loaded carts through real touch controls; preserve delivery and saved plans."""
import argparse,json,threading
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright
from browser_smoke import ready,state,tap,capture
from browser_transport import context_with,chosen,click

def run(browser,url):
    errors=[];engine=browser.browser_type.name
    for clear in (False,True):
        context,page,fixture=context_with(browser,'transport-moving-edit-fixture',errors)
        try:
            page.goto(url);ready(page);tap(page,'logistics')
            cart=state(page)['logistics']['carts'][0]
            assert cart['phase']=='to_destination' and len(cart['cargo'])==3,cart
            cargo=cart['cargo'];position=cart['position'];path=cart['path']
            chosen(page,3,4,'site4','market0');click(page,'cart_order0_0')
            page.wait_for_function('window.kikoriState.logistics.carts[0].pending_orders?.[0]?.source==="site4"')
            cart=state(page)['logistics']['carts'][0]
            assert cart['destination']=='site2' and cart['cargo']==cargo and cart['position']==position and cart['path']==path
            assert not cart['pause_requested']
            if not clear:
                chosen(page,1,2,'site2','site3');click(page,'cart_append0')
                page.wait_for_function('window.kikoriState.logistics.carts[0].pending_orders.length===2')
                click(page,'cart_remove0_1')
                page.wait_for_function('window.kikoriState.logistics.carts[0].pending_orders.length===1')
                capture(page,engine+'-live-order-change')
            # Even clearing, then adding a replacement, is allowed with cargo aboard.
            click(page,'cart_clear0')
            page.wait_for_function('window.kikoriState.logistics.carts[0].pending_orders.length===0')
            if not clear:
                chosen(page,3,4,'site4','market0');click(page,'cart_append0')
                page.wait_for_function('window.kikoriState.logistics.carts[0].pending_orders.length===1')
            capture(page,engine+('-live-order-clear' if clear else '-live-order-reserved'))
            # Every edit saves immediately. Reload directly from the still-open modal.
            page.reload();ready(page)
            if clear:
                page.wait_for_function('window.kikoriState.logistics.carts[0].phase==="parked"',timeout=90000)
                current=state(page);cart=current['logistics']['carts'][0]
                assert cart['orders']==[] and cart['pending_orders'] is None and cart['cargo']==[]
                assert current['money']==fixture['money']
                assert len(current['logistics']['sites'][3]['output'])==3
            else:
                page.wait_for_function('(money)=>window.kikoriState.money===money+120',arg=fixture['money'],timeout=120000)
                current=state(page);cart=current['logistics']['carts'][0]
                assert cart['orders']==[{'source':'site4','destination':'market0'}] and cart['pending_orders'] is None
                assert not cart['pause_requested'] and cart['cargo']==[]
            # The original logs reach their original processor exactly once.
            processor=current['logistics']['sites'][1]
            assert len(processor['input'])+len(processor['output'])==3 and current['conserved']
        except Exception:
            print('KIKORI_LIVE_ORDER_FAILED',json.dumps({'clear':clear,'cart':state(page)['logistics']['carts'][0],'errors':errors}),flush=True)
            capture(page,engine+'-live-order-failure');raise
        finally:context.close()
    assert not errors,errors
    result={'engine':engine,'loaded_change_append_delete_clear':True,'pending_save_reload':True,'original_delivery_preserved':True,'continues_new_commands':True,'errors':errors}
    Path('reports/live-orders-'+engine+'.json').write_text(json.dumps(result,indent=2));print('KIKORI_LIVE_ORDER_BROWSER',json.dumps(result),flush=True)

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
