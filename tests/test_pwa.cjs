/* Verify update policy and install UI contracts independently of browser UI. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let checks = 0;
function check(ok, message) { assert.ok(ok, message); checks++; }
class CustomEvent extends Event { constructor(type, options={}) { super(type, options); this.detail=options.detail; } }
class Element extends EventTarget {
  constructor() { super(); this.hidden=true; this.disabled=false; this.open=false; this.textContent=''; }
  showModal() { this.open=true; }
  close() { this.open=false; this.dispatchEvent(new Event('close')); }
  focus() {}
  click() { this.dispatchEvent(new Event('click')); }
}
const settle=()=>new Promise(resolve=>setImmediate(resolve));
(async () => {
  const nodes=Object.fromEntries(['app-dialog','app-description','app-install','app-update','app-status','app-close','canvas'].map(id=>[id,new Element()]));
  const window=new EventTarget();
  let messages=[], reloads=0, savedRequests=0, paused=false;
  const registration=new EventTarget();registration.waiting=null;registration.update=async()=>{};
  const serviceWorker=new EventTarget();serviceWorker.register=async()=>registration;
  window.addEventListener('kikori-save-before-update',()=>savedRequests++);
  window.addEventListener('kikori-web-modal-change',e=>paused=e.detail);
  vm.runInNewContext(fs.readFileSync('web/pwa.js','utf8'),{
    window, document:{getElementById:id=>nodes[id]},navigator:{serviceWorker,userAgent:'Chrome Android',onLine:true},
    matchMedia:()=>({matches:false}),location:{reload:()=>reloads++},CustomEvent,Event,
  });
  window.dispatchEvent(new Event('load'));await settle();
  window.KikoriInstall.open();
  check(nodes['app-dialog'].open && paused,'Install entry pauses the game');
  check(nodes['app-install'].hidden && nodes['app-description'].textContent.includes('Chrome'),'Unsupported prompt has manual Chrome instructions');
  nodes['app-close'].click();check(!paused,'Closing dialog releases its pause');
  for(const outcome of ['dismissed','accepted']) {
    const e=new Event('beforeinstallprompt',{cancelable:true});let prompted=0;
    e.prompt=async()=>{prompted++;};e.userChoice=Promise.resolve({outcome});
    window.dispatchEvent(e);check(!e.defaultPrevented,'Native Chrome promotion is allowed');
    window.KikoriInstall.open();check(!nodes['app-install'].hidden,'Install is offered only with an available prompt');
    nodes['app-install'].click();await settle();
    check(prompted===1 && nodes['app-install'].hidden,'A prompt is consumed once');
    check(nodes['app-status'].textContent.includes(outcome==='accepted'?'受け付け':'今回は'),'Prompt choice is reflected');
    nodes['app-close'].click();
  }
  registration.waiting={postMessage:message=>messages.push(message)};
  window.KikoriInstall.open();check(!nodes['app-update'].hidden,'Prepared update is reviewable');
  nodes['app-update'].click();check(savedRequests===1 && messages.length===0,'Update waits for the actual game save');
  window.dispatchEvent(new CustomEvent('kikori-update-saved',{detail:false}));
  check(!nodes['app-update'].disabled && messages.length===0,'Failed save blocks activation');
  serviceWorker.dispatchEvent(new Event('controllerchange'));check(reloads===0,'Unrequested activation never reloads a game');
  nodes['app-update'].click();window.dispatchEvent(new CustomEvent('kikori-update-saved',{detail:true}));
  check(messages.length===1 && messages[0].type==='ACTIVATE_SAVED_UPDATE','Successful save permits activation');
  serviceWorker.dispatchEvent(new Event('controllerchange'));serviceWorker.dispatchEvent(new Event('controllerchange'));
  check(reloads===1,'Requested update reloads once');
  // Exercise a real worker's request routing with in-memory network/cache APIs.
  const scope='https://example.com/kikori-godot/';
  const stores=new Map();let skip=0,claims=0;
  const cacheApi={
    async open(name){
      if(!stores.has(name)) stores.set(name,new Map());
      const store=stores.get(name);
      return {async addAll(requests){for(const r of requests)store.set(r.url,new Response('cached:'+r.url));},async match(r){return store.get(typeof r==='string'?r:r.url)?.clone();}};
    }, async keys(){return [...stores.keys()];}, async delete(name){return stores.delete(name);},
  };
  function worker(version) {
    const handlers={};
    const self={registration:{scope},clients:{claim:async()=>claims++},skipWaiting:async()=>skip++,addEventListener:(type,handler)=>handlers[type]=handler};
    vm.runInNewContext(fs.readFileSync('web/sw.js','utf8').replace('__VERSION__',JSON.stringify(version)).replace('__ASSETS__',JSON.stringify(['./index.html','./releases/'+version+'/index.pck'])),{
      self,caches:cacheApi,URL,Request,fetch:async r=>new Response('network:'+r.url),Promise,Math,
    });
    return handlers;
  }
  async function wait(handler,event={}) {let pending;handler({...event,waitUntil:p=>pending=p});await pending;}
  const a=worker('a');await wait(a.install);await wait(a.activate);
  check(skip===0 && claims===1,'First activation claims pages without forcing an update');
  const b=worker('b');await wait(b.install);check(skip===0,'Installing a new version does not skip waiting');
  await wait(b.message,{data:{type:'unrelated'}});check(skip===0,'Unrelated messages cannot activate updates');
  await wait(b.message,{data:{type:'ACTIVATE_SAVED_UPDATE'}});check(skip===1,'Only explicit saved updates skip waiting');
  await wait(b.activate);
  async function request(url,mode='cors',method='GET') {
    let result;
    b.fetch({request:{url,mode,method},respondWith:p=>result=p});
    return result ? (await result).text() : undefined;
  }
  check((await request(scope+'?app=1','navigate')).endsWith('/index.html'),'App launch query resolves the complete cached release');
  check((await request(scope+'releases/a/index.pck')).includes('/releases/a/'),'Previous open tab can still fetch its exact version');
  check(await request('https://example.com/other/index.html','navigate')===undefined,'Other projects on the same origin remain untouched');
  check(await request(scope+'index.html','cors','POST')===undefined,'Non-GET requests remain untouched');
  check(await request(scope+'unknown.json')===undefined,'Unrelated files are not captured');
  console.log('KIKORI_PWA_POLICY assertions='+checks+' failures=0');
})().catch(error=>{console.error(error);process.exitCode=1;});
