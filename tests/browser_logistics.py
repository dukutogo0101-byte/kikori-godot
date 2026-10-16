#!/usr/bin/env python3
"""Road gestures and linked transport through the actual Web UI.

Equipment scenario uses the native suite's validated earned-revenue fixture.
Only browser input mutates the running game; window diagnostics are read-only.
"""
import json,threading,math
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright
from browser_smoke import ready,state,tap,KEY

def snap(page,name): page.screenshot(path=f'reports/logistics-{name}.png')
def bring(page,key):
 for _ in range(14):
  ui=page.evaluate('window.kikoriUi');y=ui[key]['y']
  if 165<y<710: return
  page.mouse.move(185,530);page.mouse.wheel(0,240 if y>=710 else -240);page.wait_for_timeout(300)
 raise AssertionError(f'Button not reachable: {key}')
def click(page,key): bring(page,key);tap(page,key)
def select(page,key,index):
 click(page,key)
 page.wait_for_timeout(250)
 # A touch-opened Godot PopupMenu starts without a keyboard focus row.
 for _ in range(index+1): page.keyboard.press('ArrowDown')
 page.keyboard.press('Enter');page.wait_for_timeout(250)

def run(browser,url):
 fixture=json.loads(Path('reports/logistics-fixture.json').read_text())
 context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=True,locale='ja-JP')
 context.add_init_script('if(!localStorage.getItem('+json.dumps(KEY)+'))localStorage.setItem('+json.dumps(KEY)+','+json.dumps(json.dumps(fixture))+');')
 page=context.new_page();errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda e:errors.append(e.text) if e.type=='error' else None)
 page.goto(url);ready(page)
 assert state(page)['version']==4 and state(page)['conserved']
 tap(page,'logistics');assert page.evaluate('window.kikoriUi.logistics_open')
 snap(page,'panel')
 select(page,'route_destination',1) # choices: camp0, depot0, market0, market1
 page.wait_for_function('window.kikoriUi.destination_id==="depot0"',timeout=5000)
 click(page,'cart_buy');page.wait_for_function('window.kikoriState.logistics.carts.length===1')
 select(page,'route_source',1);select(page,'route_destination',2)
 page.wait_for_function('window.kikoriUi.source_id==="depot0" && window.kikoriUi.destination_id==="market0"')
 click(page,'cart_buy');page.wait_for_function('window.kikoriState.logistics.carts.length===2')
 snap(page,'routes')
 tap(page,'log_close');assert not page.evaluate('window.kikoriUi.modal')
 baseline=state(page)['sold'][0]
 page.wait_for_function('(before)=>window.kikoriState.sold[0]>before',arg=baseline,timeout=90000)
 assert state(page)['conserved']
 snap(page,'working-network')
 # Pause and resume a loaded route using the UI; verify no direct loss of cargo.
 tap(page,'logistics');click(page,'cart_pause0');tap(page,'log_close')
 page.wait_for_function('window.kikoriState.logistics.carts[0].phase==="parked"',timeout=60000)
 assert state(page)['logistics']['carts'][0]['cargo']==[]
 page.reload();ready(page)
 assert len(state(page)['logistics']['carts'])==2 and state(page)['conserved']
 # Focus camp, preview an extension, then confirm. The editor pauses logistics.
 tap(page,'logistics');select(page,'route_source',0);click(page,'source_focus')
 page.wait_for_function('window.kikoriUi.road_editing')
 page.wait_for_timeout(500)
 start=state(page)['position'];elapsed=state(page)['elapsed'];money=state(page)['money']
 before=len(state(page)['logistics']['roads'])
 # Orthographic ground projection for focus (-12,9), height 42, at 390x844.
 # Camera up uses (0,16,-17.4); look-at point is 0.6m above the ground.
 ui=page.evaluate('window.kikoriUi');scale=ui['height']/42.0
 x=ui['width']/2;y=ui['height']/2+0.6*16/math.hypot(16,17.4)*scale
 end_y=y+3*17.4/math.hypot(16,17.4)*scale
 session=context.new_cdp_session(page)
 session.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':x,'y':y}]})
 session.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':x,'y':end_y}]})
 session.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
 page.wait_for_function('window.kikoriUi.road_preview_count>=3',timeout=5000)
 assert state(page)['money']==money and len(state(page)['logistics']['roads'])==before
 assert state(page)['position']==start and state(page)['elapsed']==elapsed
 snap(page,'road-preview')
 tap(page,'road_confirm')
 page.wait_for_function('(before)=>window.kikoriState.logistics.roads.length>before',arg=before)
 after=state(page)
 assert after['money']==money-(len(after['logistics']['roads'])-before)*2
 # A canceled gesture and orientation change cannot leave an active road purchase.
 session.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':x,'y':y}]})
 session.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':[{'x':x,'y':end_y+40}]})
 session.send('Input.dispatchTouchEvent',{'type':'touchCancel','touchPoints':[]})
 page.wait_for_function('window.kikoriUi.road_preview_count===0')
 page.set_viewport_size({'width':844,'height':390})
 page.wait_for_function('window.kikoriUi.width>window.kikoriUi.height')
 assert page.evaluate('window.kikoriUi.road_preview_count')==0
 tap(page,'road_done');assert not page.evaluate('window.kikoriUi.road_editing')
 page.wait_for_timeout(3200);saved=state(page)['logistics']['roads']
 page.reload();ready(page)
 assert state(page)['logistics']['roads']==saved and state(page)['conserved']
 snap(page,'landscape')
 assert not errors,errors
 result={'real_web_ui':True,'fixture':'validated earned revenue and initial road network','two_stage_delivery':True,'pause_after_delivery':True,'road_preview_and_explicit_confirmation':True,'touch_cancel_and_rotation':True,'save_resume':True,'conserved':True,'errors':errors}
 Path('reports/logistics-browser-results.json').write_text(json.dumps(result,indent=2))
 print('KIKORI_LOGISTICS_BROWSER',json.dumps(result),flush=True)
 context.close()

def main():
 server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/web'))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  with sync_playwright() as p:
   b=p.chromium.launch(headless=True,args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
   try: run(b,f'http://127.0.0.1:{server.server_port}')
   finally: b.close()
 finally: server.shutdown()
if __name__=='__main__': main()
