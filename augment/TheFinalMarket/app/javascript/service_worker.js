// Advanced Service Worker with precaching, runtime caching, and background sync
const CACHE_VERSION = 'v2';
const CACHE_NAME = `final-market-${CACHE_VERSION}`;
const IMAGE_CACHE = `final-market-images-${CACHE_VERSION}`;
const API_CACHE = `final-market-api-${CACHE_VERSION}`;
const STATIC_CACHE = `final-market-static-${CACHE_VERSION}`;

// Maximum cache sizes
const MAX_IMAGE_CACHE_SIZE = 100;
const MAX_API_CACHE_SIZE = 50;

// Assets to precache
const PRECACHE_ASSETS = [
  '/',
  '/offline',
  '/manifest.json',
  '/icon-192x192.png',
  '/icon-512x512.png',
  '/app.css',
  '/app.js'
];

// Install event - precache assets
self.addEventListener('install', event => {
  console.log('[ServiceWorker] Installing...');
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then(cache => {
        console.log('[ServiceWorker] Precaching assets');
        return cache.addAll(PRECACHE_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - cleanup old caches
self.addEventListener('activate', event => {
  console.log('[ServiceWorker] Activating...');
  const currentCaches = [STATIC_CACHE, IMAGE_CACHE, API_CACHE];

  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames
          .filter(cacheName => cacheName.startsWith('final-market-'))
          .filter(cacheName => !currentCaches.includes(cacheName))
          .map(cacheName => {
            console.log('[ServiceWorker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          })
      );
    }).then(() => self.clients.claim())
  );
});

// Helper functions
const isApiRequest = request => {
  const url = new URL(request.url);
  return url.pathname.startsWith('/api/') || url.pathname.startsWith('/graphql');
};

const isImageRequest = request => {
  return request.destination === 'image' ||
         request.url.match(/\.(jpg|jpeg|png|gif|webp|svg|avif)$/i);
};

const isStaticAsset = request => {
  return request.destination === 'style' ||
         request.destination === 'script' ||
         request.destination === 'font';
};

// Cache size management
async function trimCache(cacheName, maxItems) {
  const cache = await caches.open(cacheName);
  const keys = await cache.keys();
  if (keys.length > maxItems) {
    await cache.delete(keys[0]);
    await trimCache(cacheName, maxItems);
  }
}

// Fetch event - handle network requests with advanced caching strategies
self.addEventListener('fetch', event => {
  // Skip cross-origin requests
  if (!event.request.url.startsWith(self.location.origin)) return;

  // Skip non-GET requests
  if (event.request.method !== 'GET') return;

  // API requests - Network-first with cache fallback
  if (isApiRequest(event.request)) {
    event.respondWith(
      fetch(event.request)
        .then(response => {
          if (response.ok) {
            const responseClone = response.clone();
            caches.open(API_CACHE).then(cache => {
              cache.put(event.request, responseClone);
              trimCache(API_CACHE, MAX_API_CACHE_SIZE);
            });
          }
          return response;
        })
        .catch(() => {
          return caches.match(event.request);
        })
    );
  }

  // Image requests - Cache-first with network fallback
  else if (isImageRequest(event.request)) {
    event.respondWith(
      caches.match(event.request)
        .then(response => {
          if (response) return response;

          return fetch(event.request)
            .then(response => {
              if (response.ok) {
                const responseClone = response.clone();
                caches.open(IMAGE_CACHE).then(cache => {
                  cache.put(event.request, responseClone);
                  trimCache(IMAGE_CACHE, MAX_IMAGE_CACHE_SIZE);
                });
              }
              return response;
            });
        })
    );
  }

  // Static assets - Cache-first
  else if (isStaticAsset(event.request)) {
    event.respondWith(
      caches.match(event.request)
        .then(response => {
          return response || fetch(event.request)
            .then(response => {
              if (response.ok) {
                const responseClone = response.clone();
                caches.open(STATIC_CACHE).then(cache => {
                  cache.put(event.request, responseClone);
                });
              }
              return response;
            });
        })
    );
  }

  // HTML pages - Stale-while-revalidate
  else {
    event.respondWith(
      caches.match(event.request)
        .then(cachedResponse => {
          const fetchPromise = fetch(event.request)
            .then(networkResponse => {
              if (networkResponse.ok) {
                caches.open(STATIC_CACHE).then(cache => {
                  cache.put(event.request, networkResponse.clone());
                });
              }
              return networkResponse;
            })
            .catch(() => {
              if (event.request.mode === 'navigate') {
                return caches.match('/offline');
              }
              return Response.error();
            });

          return cachedResponse || fetchPromise;
        })
    );
  }
});

// Push event - handle push notifications
self.addEventListener('push', event => {
  const data = event.data.json();
  
  const options = {
    body: data.body,
    icon: '/icon-192x192.png',
    badge: '/badge.png',
    vibrate: [100, 50, 100],
    data: {
      url: data.url
    },
    actions: data.actions || []
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// Notification click event
self.addEventListener('notificationclick', event => {
  event.notification.close();

  if (event.action) {
    // Handle notification action buttons
    clients.openWindow(event.action);
  } else {
    // Handle notification click
    event.waitUntil(
      clients.matchAll({ type: 'window' })
        .then(clientList => {
          const url = event.notification.data.url;

          for (const client of clientList) {
            if (client.url === url && 'focus' in client) {
              return client.focus();
            }
          }

          if (clients.openWindow) {
            return clients.openWindow(url);
          }
        })
    );
  }
});

// Background Sync - Retry failed requests
self.addEventListener('sync', event => {
  console.log('[ServiceWorker] Background sync:', event.tag);

  if (event.tag === 'sync-cart') {
    event.waitUntil(syncCart());
  } else if (event.tag === 'sync-wishlist') {
    event.waitUntil(syncWishlist());
  } else if (event.tag === 'sync-views') {
    event.waitUntil(syncProductViews());
  }
});

async function syncCart() {
  try {
    const cache = await caches.open('pending-requests');
    const requests = await cache.keys();
    const cartRequests = requests.filter(req => req.url.includes('/cart'));

    for (const request of cartRequests) {
      try {
        await fetch(request.clone());
        await cache.delete(request);
      } catch (error) {
        console.error('[ServiceWorker] Failed to sync cart request:', error);
      }
    }
  } catch (error) {
    console.error('[ServiceWorker] Cart sync failed:', error);
  }
}

async function syncWishlist() {
  try {
    const cache = await caches.open('pending-requests');
    const requests = await cache.keys();
    const wishlistRequests = requests.filter(req => req.url.includes('/wishlist'));

    for (const request of wishlistRequests) {
      try {
        await fetch(request.clone());
        await cache.delete(request);
      } catch (error) {
        console.error('[ServiceWorker] Failed to sync wishlist request:', error);
      }
    }
  } catch (error) {
    console.error('[ServiceWorker] Wishlist sync failed:', error);
  }
}

async function syncProductViews() {
  try {
    const cache = await caches.open('pending-requests');
    const requests = await cache.keys();
    const viewRequests = requests.filter(req => req.url.includes('/product_views'));

    for (const request of viewRequests) {
      try {
        await fetch(request.clone());
        await cache.delete(request);
      } catch (error) {
        console.error('[ServiceWorker] Failed to sync product view:', error);
      }
    }
  } catch (error) {
    console.error('[ServiceWorker] Product views sync failed:', error);
  }
}

// Message event - Handle messages from clients
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(STATIC_CACHE).then(cache => {
        return cache.addAll(event.data.urls);
      })
    );
  }
});