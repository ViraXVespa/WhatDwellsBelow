// Service worker for job-finished notifications only (no caching). Browsers register it only in a
// secure context (https or localhost); on a plain http LAN address the page falls back to a title flash.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || "/";
  event.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((wins) => {
    for (const win of wins) {
      if ("focus" in win) { win.navigate && win.navigate(url); return win.focus(); }
    }
    return self.clients.openWindow(url);
  }));
});
