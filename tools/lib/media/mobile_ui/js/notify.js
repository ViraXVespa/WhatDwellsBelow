// Job-finished alerts. The Notification API needs a secure context (https or localhost). On a plain
// http://<lan-ip>:8189 page Android Chrome hides it, so the fallback flashes the tab title and favicon.
const BASE_TITLE = "Pipeline Studio";
let flashTimer = 0;
let swReg = null;

export function support() {
  const api = "Notification" in window;
  return {
    secure: window.isSecureContext,
    api,
    permission: api ? Notification.permission : "unavailable",
    usable: window.isSecureContext && api,
  };
}

export async function setup() {
  if (window.isSecureContext && "serviceWorker" in navigator) {
    try { swReg = await navigator.serviceWorker.register("sw.js"); } catch (e) { swReg = null; }
  }
  document.addEventListener("visibilitychange", () => { if (!document.hidden) stopFlash(); });
}

// Call from a tap. Resolves with a short status line for the page.
export async function enable() {
  const s = support();
  if (!s.secure) return "Alerts need https or localhost. This page is plain http on the LAN, so a finished job flashes the tab title instead.";
  if (!s.api) return "This browser has no notification support. A finished job flashes the tab title instead.";
  if (Notification.permission === "granted") return "Alerts are on.";
  const p = await Notification.requestPermission();
  return p === "granted" ? "Alerts are on." : "Alerts were not allowed. A finished job flashes the tab title instead.";
}

export async function jobFinished(job, url) {
  if (!document.hidden) return;
  const title = `${job.cmd} ${job.status === "done" ? "finished" : job.status}`;
  const body = (job.subject ? job.subject + " - " : "") + (job.stage || "");
  const s = support();
  if (s.usable && Notification.permission === "granted") {
    try {
      if (swReg && swReg.showNotification) {
        await swReg.showNotification(title, { body, tag: "job-" + job.id, data: { url }, icon: "icon.svg" });
        return;
      }
      new Notification(title, { body, tag: "job-" + job.id, icon: "icon.svg" });
      return;
    } catch (e) { /* Android Chrome refuses `new Notification` without a worker: fall through */ }
  }
  flash(title);
}

function badgeIcon(on) {
  const link = document.querySelector("link[rel=icon]");
  if (!link) return;
  link.href = on
    ? "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="12" fill="#17141d"/><circle cx="32" cy="32" r="20" fill="#e0605a"/></svg>')
    : "icon.svg";
}

function flash(msg) {
  stopFlash();
  let on = false;
  flashTimer = setInterval(() => {
    on = !on;
    document.title = on ? "\u25CF " + msg : BASE_TITLE;
    badgeIcon(on);
  }, 1000);
}

function stopFlash() {
  if (flashTimer) clearInterval(flashTimer);
  flashTimer = 0;
  document.title = BASE_TITLE;
  badgeIcon(false);
}
