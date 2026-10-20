#!/usr/bin/env python3
"""Focused logistics scrolling check: swipes over controls cancel accidental taps."""
import argparse,json,threading
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright
from browser_smoke import ready,state,tap,capture

def run(browser,url):
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=browser.browser_type.name=='chromium')
    page=context.new_page();errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(url);ready(page);tap(page,'logistics')
    def y():return page.evaluate('window.kikoriUi.road_editor.y')
    def swipe(start,end):
        if browser.browser_type.name=='chromium':
            cdp=context.new_cdp_session(page)
            cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':180,'y':start}]})
            for i in range(1,13):
                cdp.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':180,'y':start+(end-start)*i/12}]});page.wait_for_timeout(20)
            cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]});cdp.detach()
        else:
            page.mouse.move(180,start);page.mouse.down();page.mouse.move(180,end,steps=12);page.mouse.up()
        page.wait_for_timeout(450)
    before=y();start=page.evaluate('window.kikoriUi.build_size.y')
    swipe(start,max(145,start-180))
    assert y()<before-60,{'before':before,'after':y()}
    assert page.evaluate('window.kikoriUi.logistics_open && !window.kikoriUi.large_build'),'Swiping on a button must scroll without activating it'
    swipe(240,590)
    # Allow native momentum to settle, then verify an ordinary tap still works.
    page.wait_for_timeout(1200)
    assert y()>before-40
    tap(page,'build_size');assert page.evaluate('window.kikoriUi.large_build')
    assert page.evaluate('window.kikoriUi.logistics_open') and state(page)['money']==0
    capture(page,browser.browser_type.name+'-logistics-scroll')
    assert not errors,errors
    print('KIKORI_SCROLL_BROWSER',json.dumps({'engine':browser.browser_type.name,'button_swipe':True,'reverse_swipe':True,'tap_preserved':True,'errors':errors}),flush=True)
    context.close()

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
