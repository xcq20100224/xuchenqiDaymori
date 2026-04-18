const CACHE_NAME = 'daymori-pwa-v23';
const APP_SHELL = [
  './',
  './Daymori.html',
  './dream.html',
  './manifest.json',
  './favicon.svg',
  './Andrew.m4a'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
    )).then(() => self.clients.claim())
  );
});

self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const isNavigateRequest = event.request.mode === 'navigate';
  const requestUrl = new URL(event.request.url);
  const isDreamNavigate = requestUrl.pathname.endsWith('/dream.html') || requestUrl.pathname.endsWith('/dream');

  if (isNavigateRequest) {
    event.respondWith(
      fetch(event.request)
        .then(response => {
          if (response && response.status === 200 && response.type !== 'opaque') {
            const cloned = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
          }
          return response;
        })
        .catch(() => caches.match(event.request).then(cached => cached || caches.match(isDreamNavigate ? './dream.html' : './Daymori.html')))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request)
        .then(response => {
          if (!response || response.status !== 200 || response.type === 'opaque') {
            return response;
          }
          const cloned = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
          return response;
        })
        .catch(() => {
          if (isNavigateRequest) {
            return caches.match(isDreamNavigate ? './dream.html' : './Daymori.html');
          }
          return Response.error();
        });
    })
  );
});