// Small DOM helpers shared by every screen.
export function h(tag, attrs, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === null || v === undefined || v === false) continue;
    if (k === "class") el.className = v;
    else if (k === "text") el.textContent = v;
    else if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2), v);
    else if (k === "style" && typeof v === "object") Object.assign(el.style, v);
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const kid of kids.flat(Infinity)) {
    if (kid === null || kid === undefined || kid === false) continue;
    el.append(kid instanceof Node ? kid : document.createTextNode(String(kid)));
  }
  return el;
}

let toastTimer = 0;
export function toast(msg, ms = 2200) {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove("show"), ms);
}

export function haptic(ms = 12) { if (navigator.vibrate) navigator.vibrate(ms); }

const sheetEl = () => document.getElementById("sheet");
const backEl = () => document.getElementById("sheet-back");
export function openSheet(...content) {
  const s = sheetEl();
  s.replaceChildren(...content.flat(Infinity).filter((c) => c != null && c !== false));
  s.hidden = false;
  backEl().hidden = false;
  backEl().onclick = closeSheet;
}
export function closeSheet() { sheetEl().hidden = true; backEl().hidden = true; }

// Bottom sheet with a title, text and buttons; resolves with the chosen value (null on dismiss).
export function choose(title, body, options) {
  return new Promise((resolve) => {
    const done = (v) => { closeSheet(); resolve(v); };
    backEl().onclick = () => done(null);
    openSheet(
      h("h2", { text: title }),
      body ? (body instanceof Node ? body : h("p", { class: "muted", text: body })) : null,
      h("div", { class: "list" }, options.map((o) => h("button", { class: "btn full " + (o.cls || ""), onclick: () => done(o.value) }, o.label))),
      h("button", { class: "btn ghost full", style: { marginTop: "8px" }, onclick: () => done(null) }, "Cancel"),
    );
    backEl().onclick = () => done(null);
  });
}

const NOT_WIRED = "That is not connected on the PC yet.";

export function errorBox(data, extra) {
  const wired = data && data.not_wired;
  const msg = wired ? NOT_WIRED : (data && data.error) || "Something went wrong.";
  return h("div", { class: "error-box" }, h("b", {}, msg),
    wired ? h("details", { class: "small" }, h("summary", {}, "Details"), h("div", { class: "mono" }, `${data.not_wired}: ${data.error}`)) : null, extra || null);
}

export function showError(res) {
  const d = res.data || {};
  toast(d.not_wired ? NOT_WIRED : d.error || "Something went wrong.", 4200);
}

// Hold (500 ms) or right-click runs onHold; a plain tap runs onTap.
export function holdable(el, onHold, onTap) {
  let timer = 0, held = false, sx = 0, sy = 0;
  el.addEventListener("pointerdown", (e) => {
    held = false; sx = e.clientX; sy = e.clientY;
    timer = setTimeout(() => { held = true; haptic(20); onHold(e); }, 500);
  });
  const stop = () => clearTimeout(timer);
  el.addEventListener("pointermove", (e) => { if (Math.abs(e.clientX - sx) + Math.abs(e.clientY - sy) > 12) stop(); });
  el.addEventListener("pointerup", stop);
  el.addEventListener("pointercancel", stop);
  el.addEventListener("contextmenu", (e) => { e.preventDefault(); stop(); if (!held) onHold(e); held = true; });
  el.addEventListener("click", (e) => { if (held) { e.preventDefault(); held = false; return; } if (onTap) onTap(e); });
  return el;
}

export function when(ts) {
  if (!ts) return "";
  const d = typeof ts === "number" ? new Date(ts * 1000) : new Date(ts);
  if (isNaN(d)) return "";
  const s = (Date.now() - d.getTime()) / 1000;
  if (s < 60) return "just now";
  if (s < 3600) return Math.round(s / 60) + " min ago";
  if (s < 86400) return Math.round(s / 3600) + " h ago";
  return d.toLocaleDateString();
}

export function basename(p) { return String(p || "").split("/").pop(); }
