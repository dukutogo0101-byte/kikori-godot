#!/usr/bin/env python3
"""Actual touch input: straight strokes, preserved drafts, pan, edge scrolling,
undo, orientation, a single paid confirmation, and carts on free original roads.
"""
import argparse,json,math,threading
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright
from browser_smoke import ready,state,tap,capture,KEY
from browser_logistics import click
from browser_facilities import frames,project,screen_tap

def point(page,x,z):
    p=project(page,x,z);ui=page.evaluate('window.kikoriUi');b=page.locator('#canvas').bounding_box()
    return {'x':b['x']+p['x']/ui['width']*b['width'],'y':b['y']+p['y']/ui['height']*b['height']}

def draw(page,world_points):
    points=[point(page,*p) for p in world_points]
    if page.context.browser.browser_type.name=='chromium':
        session=page.context.new_cdp_session(page)
        session.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[points[0]]})
        for p in points[1:]:session.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[p]})
        session.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]});session.detach()
    else:
        page.mouse.move(**points[0]);page.mouse.down()
        for p in points[1:]:page.mouse.move(**p,steps=2)
        page.mouse.up()
    frames(page)

def pan_to(page,x,z):
    tap(page,'road_pan')
    for _ in range(12):
        ui=page.evaluate('window.kikoriUi');focus=ui['planning_focus'];dx=x-focus[0];dz=z-focus[1]
        if max(abs(dx),abs(dz))<.25:return
        scale=ui['height']/state(page)['render']['camera_size']
        page.mouse.move(195,400);page.mouse.down()
        page.mouse.move(195-max(-4,min(4,dx))*scale,400-max(-4,min(4,dz))*17.4/math.hypot(16,17.4)*scale,steps=4)
        page.mouse.up();frames(page)
    raise AssertionError(('Cannot pan to target',page.evaluate('window.kikoriUi.planning_focus')))

def context_for(browser,name,errors):
    fixture=json.loads(Path('reports/'+name+'.json').read_text())
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=browser.browser_type.name=='chromium',locale='ja-JP')
    context.add_init_script('if(!localStorage.getItem('+json.dumps(KEY)+'))localStorage.setItem('+json.dumps(KEY)+','+json.dumps(json.dumps(fixture))+');')
    page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)));page.on('console',lambda e:errors.append(e.text) if e.type=='error' else None)
    return context,page,fixture

def run(browser,url):
    errors=[];engine=browser.browser_type.name
    context,page,fixture=context_for(browser,'production-start-fixture',errors)
    try:
        page.goto(url);ready(page);tap(page,'logistics');click(page,'road_editor')
        page.wait_for_function('window.kikoriUi.road_editing')
        funds=state(page)['money'];elapsed=state(page)['elapsed']
        draw(page,[(-6,13),(-5,14),(-6,16),(-5,18),(-6,20)])
        preview=page.evaluate('window.kikoriUi.road_preview')
        assert len(preview)>=8 and all(p[0]==-6 for p in preview),preview
        assert state(page)['money']==funds and state(page)['elapsed']==elapsed and state(page)['logistics']['roads']==[]
        tap(page,'road_pan');before=page.evaluate('window.kikoriUi.planning_focus')
        page.mouse.move(195,400);page.mouse.down();page.mouse.move(130,400,steps=4);page.mouse.up();frames(page)
        assert page.evaluate('window.kikoriUi.planning_focus')[0]>before[0]+1
        assert page.evaluate('window.kikoriUi.road_preview')==preview
        tap(page,'road_build');screen_tap(page,project(page,-6,24))
        assert page.evaluate('window.kikoriUi.road_preview')[-1]==[-6,24]
        tap(page,'road_undo');assert page.evaluate('window.kikoriUi.road_preview')==preview
        page.set_viewport_size({'width':844,'height':390});page.wait_for_function('window.kikoriUi.width>window.kikoriUi.height');frames(page)
        assert page.evaluate('window.kikoriUi.road_preview')==preview
        ui=page.evaluate('window.kikoriUi');assert 0<ui['road_confirm']['y']<390 and ui['road_build']['y']<60
        capture(page,engine+'-road-draft-landscape')
        page.set_viewport_size({'width':390,'height':844});page.wait_for_function('window.kikoriUi.width<window.kikoriUi.height');frames(page)
        tap(page,'road_shape_button');screen_tap(page,project(page,-2,24))
        corner=page.evaluate('window.kikoriUi.road_preview')
        assert corner[-1]==[-2,24] and all(abs(a[0]-b[0])+abs(a[1]-b[1])==1 for a,b in zip(corner,corner[1:]))
        tap(page,'road_clear');tap(page,'road_shape_button')
        page.mouse.move(170,380);page.mouse.down();page.mouse.move(376,380,steps=4)
        focus=page.evaluate('window.kikoriUi.planning_focus')[0]
        page.wait_for_function('(x)=>window.kikoriUi.planning_focus[0]>x+5 && window.kikoriUi.road_preview_count>10',arg=focus,timeout=20000)
        page.mouse.up();frames(page)
        assert state(page)['money']==funds and page.evaluate('window.kikoriUi.road_history')==1
        tap(page,'road_clear');pan_to(page,-4,10);tap(page,'road_build')
        draw(page,[(-6,13),(-6,18)])
        cost=page.evaluate('window.kikoriUi.road_cost');assert cost==12,cost
        tap(page,'road_confirm');page.wait_for_function('window.kikoriState.logistics.roads.length===6')
        assert state(page)['money']==funds-cost
        tap(page,'road_done');assert not page.evaluate('window.kikoriUi.road_editing')
        page.reload();ready(page)
        assert len(state(page)['logistics']['roads'])==6 and state(page)['money']==funds-cost and state(page)['conserved']
    except Exception:
        print('KIKORI_ROADS_FAILED',json.dumps({'ui':page.evaluate('window.kikoriUi'),'errors':errors}),flush=True)
        capture(page,engine+'-road-failure');raise
    finally:context.close()
    context,page,fixture=context_for(browser,'roads-existing-fixture',errors)
    try:
        page.goto(url);ready(page);assert state(page)['logistics']['roads']==[]
        tap(page,'logistics');click(page,'cart_buy')
        page.wait_for_function('window.kikoriState.logistics.carts.length===1');tap(page,'log_close')
        expected=fixture['money']-120+30
        page.wait_for_function('(n)=>window.kikoriState.money===n',arg=expected,timeout=90000)
        assert state(page)['logistics']['roads']==[] and state(page)['conserved']
        page.wait_for_timeout(3300);page.reload();ready(page)
        assert len(state(page)['logistics']['carts'])==1 and state(page)['money']==expected
    finally:context.close()
    assert not errors,errors
    result={'engine':engine,'jitter_free_straight_line':True,'pan_preserves_draft':True,'extend_after_pan':True,'undo':True,'corner_route':True,'edge_scroll':True,'rotation_preserves_draft':True,'single_confirmation':True,'existing_roads_deliver_without_paving':True,'save_resume':True,'errors':errors}
    Path('reports/road-building-'+engine+'.json').write_text(json.dumps(result,indent=2));print('KIKORI_ROADS_BROWSER',json.dumps(result),flush=True)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--engine',choices=['chromium','webkit'],default='chromium');args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/web'));threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        with sync_playwright() as p:
            browser=getattr(p,args.engine).launch(headless=False if args.engine=='webkit' else True,args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] if args.engine=='chromium' else [])
            try:run(browser,f'http://127.0.0.1:{server.server_port}')
            finally:browser.close()
    finally:server.shutdown()
if __name__=='__main__':main()
