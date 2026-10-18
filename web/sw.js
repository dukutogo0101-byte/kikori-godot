/* Generated constants are inserted by tools/build_pwa.py. */
const VERSION = __VERSION__;
const ASSETS = __ASSETS__;
const PREFIX = 'kikori:' + new URL(self.registration.scope).pathname + ':';
const CACHE = PREFIX + VERSION;
const absolute = path => new URL(path, self.registration.scope).href;
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE);
      await cache.addAll(ASSETS.map(path => new Request(absolute(path), {cache: 'reload'})));
    } catch (error) { await caches.delete(CACHE); throw error; }
    // Waiting keeps an active game on its complete current release.
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = (await caches.keys()).filter(key => key.startsWith(PREFIX));
    // Retain the preceding release for another already-open tab's asset URLs.
    const obsolete = names.filter(key => key !== CACHE).slice(0, Math.max(0, names.length - 2));
    await Promise.all(obsolete.map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});
self.addEventListener('message', event => {
  if (event.data?.type === 'ACTIVATE_SAVED_UPDATE') event.waitUntil(self.skipWaiting());
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url), scope = new URL(self.registration.scope);
  if (event.request.method !== 'GET' || url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) return;
  const navigation = event.request.mode === 'navigate';
  if (navigation && url.pathname !== scope.pathname && url.pathname !== scope.pathname + 'index.html') return;
  const currentAsset = ASSETS.some(path => absolute(path) === url.href);
  const releaseAsset = url.pathname.startsWith(scope.pathname + 'releases/');
  if (!navigation && !currentAsset && !releaseAsset) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const request = navigation ? absolute('./index.html') : event.request;
    const hit = await cache.match(request);
    if (hit) return hit;
    if (releaseAsset) {
      for (const name of await caches.keys()) {
        if (!name.startsWith(PREFIX) || name === CACHE) continue;
        const previous = await (await caches.open(name)).match(request);
        if (previous) return previous;
      }
    }
    return fetch(event.request);
  })());
});
