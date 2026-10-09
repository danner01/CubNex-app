// Service worker de Firebase Cloud Messaging para la PWA ConKkao.
// Recibe las notificaciones push cuando la web esta en segundo plano o cerrada.
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBcyLlU6iSXsORdCYKDrfJ2xJPzELrN7pA',
  authDomain: 'supermarkercuba.firebaseapp.com',
  projectId: 'supermarkercuba',
  storageBucket: 'supermarkercuba.firebasestorage.app',
  messagingSenderId: '182405994803',
  appId: '1:182405994803:web:1c60a96012584f4081c646',
  measurementId: 'G-CLW9FWTF67',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || data.titulo || 'ConKkao';
  const body =
    notification.body || data.mensaje || 'Nueva notificacion recibida.';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data,
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ('focus' in client) {
            return client.focus();
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow('/');
        }
        return undefined;
      })
  );
});
