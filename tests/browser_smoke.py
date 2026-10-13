#!/usr/bin/env python3
"""Play the direct-control loop through real browser input, never state mutation."""
import argparse,base64,json,os,sys,time,threading
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright

def capture(page,name):
 data=page.screenshot(path=f'reports/{name}.png')
 os.set_blocking(sys.stdout.fileno(),True)
 code=base64.b64encode(data).decode()
 for i in range(0,len(code),2048): print(f'KIKORI_PREVIEW_DATA {name} '+code[i:i+2048],flush=True)

def state(page): return page.evaluate('window.kikoriState')
def move(page,x,z):
 started=time.monotonic()
 while time.monotonic()-started < 20:
  p=state(page)['position']; dx=x-p[0];dz=z-p[1]
  if abs(dx)<0.17 and abs(dz)<0.17: return
  keys=[]
  if abs(dx)>0.15: keys.append('d' if dx>0 else 'a')
  if abs(dz)>0.15: keys.append('s' if dz>0 else 'w')
  for k in keys: page.keyboard.down(k)
  page.wait_for_timeout(70)
  for k in keys: page.keyboard.up(k)
  page.wait_for_timeout(140)
 raise AssertionError(f'Movement stuck {state(page)} to {x,z}')
def inspect(browser,url,engine):
 context=browser.new_context(viewport={'width':390,'height':844},is_mobile=True,has_touch=True,locale='ja-JP')
 page=context.new_page(); errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.on('console',lambda e:errors.append(e.text) if e.type=='error' else None)
 page.goto(url);page.wait_for_function('window.kikoriReady && window.kikoriState',timeout=90000)
 move(page,0,3.1);move(page,-2.2,3.1)
 page.wait_for_function('window.kikoriState.bag>=3',timeout=15000)
 if engine=='chromium':capture(page,engine+'-carry')
 move(page,0,3.1);move(page,0,9);move(page,4,9)
 page.wait_for_function('window.kikoriState.money>=30',timeout=15000)
 assert state(page)['bag']==0
 if engine=='chromium':capture(page,engine+'-sale')
 assert page.evaluate("document.querySelector('#canvas').getContext('webgl2').getError()") == 0
 assert not errors,errors
 result={'engine':engine,'state':state(page),'errors':errors}
 context.close();return result

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--engine',choices=['all','chromium','webkit'],default='all');parser.add_argument('--url');args=parser.parse_args()
 Path('reports').mkdir(exist_ok=True);server=None;url=args.url
 if not url:
  server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/web'))
  threading.Thread(target=server.serve_forever,daemon=True).start();url=f'http://127.0.0.1:{server.server_port}'
 try:
  with sync_playwright() as p:
   for engine in (['chromium','webkit'] if args.engine=='all' else [args.engine]):
    opts={'headless':engine!='webkit'}
    if engine=='chromium':opts['args']=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']
    browser=getattr(p,engine).launch(**opts)
    try:
     result=inspect(browser,url,engine);Path(f'reports/{engine}-results.json').write_text(json.dumps(result,indent=2));print('KIKORI_BROWSER_RESULT',json.dumps(result),flush=True)
    finally:browser.close()
 finally:
  if server:server.shutdown()
if __name__=='__main__':main()
