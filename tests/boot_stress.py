import threading,json,os
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory='build/debug'));threading.Thread(target=server.serve_forever,daemon=True).start()
with sync_playwright() as p:
 browser=p.webkit.launch(headless=False)
 failures=0
 for i in range(12):
  c=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=True)
  page=c.new_page();errors=[]
  page.on('console',lambda e:print('BOOT_CONSOLE',e.type,e.text,flush=True))
  page.on('pageerror',lambda e:(errors.append(str(e)),print('BOOT_JS_STACK',e.stack,flush=True)))
  page.goto(f'http://127.0.0.1:{server.server_port}/?boot={i}')
  try: page.wait_for_function('window.kikoriReady && window.kikoriState',timeout=20000,polling=100);page.wait_for_timeout(400)
  except Exception as e: failures+=1;print('BOOT_FAILED',i,str(e),flush=True)
  print('BOOT_RESULT',i,page.evaluate('window.kikoriState?.version'),errors,flush=True);c.close()
 browser.close()
server.shutdown()
assert failures==0,failures
