#!/usr/bin/env python3
import os,json,shutil
from pathlib import Path
from playwright.sync_api import sync_playwright
from browser_logistics import run
Path('reports').mkdir(exist_ok=True)
shutil.copyfile('tests/fixtures/public-logistics.json','reports/logistics-fixture.json')
url=os.environ['PAGE_URL']
with sync_playwright() as p:
 browser=p.chromium.launch(headless=True,args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
 try: run(browser,url)
 finally: browser.close()
print('KIKORI_PUBLIC_LOGISTICS_URL',url,flush=True)
