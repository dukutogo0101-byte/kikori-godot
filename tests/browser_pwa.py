#!/usr/bin/env python3
"""Check real Chrome installability, offline boot and saved, coherent updates."""
import hashlib
import json
import shutil
import struct
import tempfile
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_smoke import ready, state, KEY

def run(browser, url, site):
    fixture=json.loads(Path('reports/tools-loaded-fixture.json').read_text())
    context=browser.new_context(viewport={'width':390,'height':844},has_touch=True,is_mobile=True,locale='ja-JP')
    context.add_init_script('if(!localStorage.getItem('+json.dumps(KEY)+'))localStorage.setItem('+json.dumps(KEY)+','+json.dumps(json.dumps(fixture))+');')
    errors=[]
    page=context.new_page()
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda e:errors.append(e.text) if e.type=='error' else None)
    page.goto(url);ready(page)
    page.wait_for_function("navigator.serviceWorker.controller",timeout=90000)
    page.evaluate('navigator.serviceWorker.ready')
    manifest=page.evaluate("fetch('manifest.webmanifest').then(r=>r.json())")
    assert manifest['display']=='standalone' and manifest['scope']=='./' and manifest['id']=='./'
    assert manifest['start_url']=='./?app=1'
    for icon in manifest['icons']:
        data=page.request.get(url+'/'+icon['src']).body()
        width,height=struct.unpack('>II',data[16:24])
        assert icon['sizes']==f'{width}x{height}' and width in [192,512]
    protocol=context.new_cdp_session(page)
    app=protocol.send('Page.getAppManifest')
    assert not app.get('errors'),app
    # This checks Chrome's real installability audit, independently of the UI
    # harness below. OS installation/automatic prompt timing remain browser UI.
    installability=protocol.send('Page.getInstallabilityErrors')
    assert not installability.get('installabilityErrors'),installability
    old=page.evaluate('window.kikoriBuild')
    cargo=state(page)['bag']
    # Simulate only the prompt's responses to test our UI's accept/dismiss paths.
    # Never call this a real OS install or a real browser-generated prompt.
    page.evaluate("""() => {
      const event=new Event('beforeinstallprompt',{cancelable:true});
      event.prompt=async()=>{window.testPromptCalls=(window.testPromptCalls||0)+1;};
      event.userChoice=Promise.resolve({outcome:'dismissed'});
      window.dispatchEvent(event);window.testDefaultAllowed=!event.defaultPrevented;
      window.KikoriInstall.open();
    }""")
    assert page.evaluate('window.testDefaultAllowed'),'Native Chrome promotion is not suppressed'
    page.locator('#app-install').click()
    page.wait_for_function("document.querySelector('#app-status').textContent.includes('今回は')")
    assert page.evaluate('window.testPromptCalls')==1
    assert page.locator('#app-install').is_hidden()
    page.locator('#app-close').click()
    # A second open tab must continue rendering its old version while B waits.
    other=context.new_page();other.goto(url);ready(other)
    new=hashlib.sha256((old+'-update-test').encode()).hexdigest()[:16]
    release=site/'releases'/old
    release.rename(site/'releases'/new)
    for name in ['index.html','sw.js']:
        p=site/name;p.write_text(p.read_text().replace(old,new))
    page.evaluate('navigator.serviceWorker.getRegistration().then(r=>r.update())')
    page.wait_for_function('navigator.serviceWorker.getRegistration().then(r=>!!r.waiting)',timeout=90000)
    assert page.evaluate('window.kikoriBuild')==old
    assert other.evaluate('window.kikoriBuild')==old
    assert page.request.get(url+'/releases/'+old+'/index.js').status==404,'Old URL really vanished from origin'
    old_asset=page.evaluate('(old)=>fetch("./releases/"+old+"/index.js").then(r=>r.status)',old)
    assert old_asset==200,'Active release survives a changed origin'
    page.evaluate('window.KikoriInstall.open()')
    page.wait_for_function("!document.querySelector('#app-update').hidden")
    page.locator('#app-update').click()
    page.wait_for_function('(build)=>window.kikoriReady && window.kikoriBuild===build',arg=new,timeout=90000)
    ready(page)
    assert state(page)['bag']==cargo and state(page)['money']==fixture['money'] and state(page)['conserved']
    assert other.evaluate('window.kikoriBuild')==old,'Other playing tabs are not forcibly reloaded'
    assert other.evaluate('(old)=>fetch("./releases/"+old+"/index.js").then(r=>r.status)',old)==200
    context.set_offline(True)
    page.reload();ready(page)
    assert page.evaluate('window.kikoriBuild')==new and state(page)['bag']==cargo and state(page)['conserved']
    assert state(page)['objects']['rendered_cargo']==128
    context.set_offline(False)
    # Refusing to update without an actual successful save is part of the UI
    # contract. Test that negative acknowledgement without replacing game state.
    page.evaluate("""() => {
      window.KikoriInstall.open();
      window.dispatchEvent(new CustomEvent('kikori-update-saved',{detail:false}));
    }""")
    assert '中止' in page.locator('#app-status').inner_text()
    page.locator('#app-close').click()
    assert not errors,errors
    result={'chrome_installability_errors':installability['installabilityErrors'],'manifest':manifest,
            'offline_actual_game_boot':True,'saved_update':True,'parallel_tab_preserved':True,
            'version_before':old,'version_after':new,'rendered_offline_cargo':128,'prompt_ui_dismissal':True,'errors':errors}
    Path('reports/pwa-browser-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print('KIKORI_PWA_BROWSER',json.dumps(result,ensure_ascii=False),flush=True)
    context.close()

def main():
    with tempfile.TemporaryDirectory(prefix='kikori-pwa-') as directory:
        site=Path(directory)/'site';shutil.copytree('build/web',site)
        server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(site)))
        threading.Thread(target=server.serve_forever,daemon=True).start()
        try:
            with sync_playwright() as p:
                browser=p.chromium.launch(headless=True,args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
                try:run(browser,f'http://127.0.0.1:{server.server_port}',site)
                finally:browser.close()
        finally:server.shutdown()
if __name__=='__main__':main()
