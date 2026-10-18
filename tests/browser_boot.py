#!/usr/bin/env python3
"""Repeat fresh Web runtime creation; never retry or suppress a failed boot."""
import argparse,json,threading
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright

def verify(browser,url,count):
 for index in range(count):
  context=browser.new_context(viewport={'width':390,'height':844},is_mobile=True,has_touch=True)
  page=context.new_page();errors=[]
  page.on('pageerror',lambda e:errors.append(e.stack))
  page.on('console',lambda e:errors.append(e.text) if e.type=='error' else None)
  try:
   page.goto(url)
   page.wait_for_function('window.kikoriReady && window.kikoriState || window.kikoriLoadError',timeout=30000,polling=100)
   page.wait_for_timeout(350)
   data=page.evaluate('({state:window.kikoriState,ui:window.kikoriUi,error:window.kikoriLoadError})')
   assert not errors and not data.get('error'),errors or data
   assert data['state']['version']==6 and data['state']['conserved'] and data['state']['money']==0,data
   assert data['ui']['logistics'] and not data['ui']['modal'],data['ui']
   print('KIKORI_FRESH_BOOT',index+1,'passed',flush=True)
  except Exception:
   print('KIKORI_BOOT_FAILURE',index+1,errors,flush=True)
   raise
  finally:context.close()
 return {'fresh_boots':count,'errors':[]}

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--engine',choices=['chromium','webkit'],required=True);parser.add_argument('--repeat',type=int,default=20)
 args=parser.parse_args();assert 1<=args.repeat<=100
 server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/web'))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  with sync_playwright() as p:
   opts={'headless':args.engine!='webkit'}
   if args.engine=='chromium':opts['args']=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']
   browser=getattr(p,args.engine).launch(**opts)
   try:result=verify(browser,f'http://127.0.0.1:{server.server_port}',args.repeat)
   finally:browser.close()
   Path(f'reports/{args.engine}-boot-results.json').write_text(json.dumps(result,indent=2))
   print('KIKORI_BOOT_STRESS',args.engine,json.dumps(result),flush=True)
 finally:server.shutdown()
if __name__=='__main__':main()
