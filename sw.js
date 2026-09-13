// Korrutaja kolis Harjutaja alla (harjutaja.silverjaanus.com/korrutaja/).
// See service worker ei teeninda enam midagi - ta ainult koristab enda jarel:
// kustutab vana rakenduse vahemalud ja votab ennast maha, et vanad seadmed
// ei saaks enam vahemalust vana Korrutajat katte, vaid naeksid kolimise teadet.
// localStorage jaab puutumata - seal on kasutaja edenemine, mida vii-ule.html vajab.
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys()
      .then(function (ks) {
        return Promise.all(ks.map(function (k) { return caches.delete(k); }));
      })
      .then(function () { return self.registration.unregister(); })
      .then(function () { return self.clients.claim(); })
      .catch(function () {})
  );
});
// fetch-kaitlejat teadlikult ei ole: koik paringud lahevad otse vorku.
