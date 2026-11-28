// Pipeline studio: hash router, header, tabs, job badge. Screens live in views_*.js.
import * as jobs from "./jobs.js";
import * as notify from "./notify.js";
import { app, loadInfo } from "./state.js";
import { closeSheet, errorBox, h } from "./ui.js";
import { coverage, home, newSubject, typeList } from "./views_home.js";
import { step, subject } from "./views_subject.js";
import { action, adjust, picture } from "./views_picture.js";
import { jobView, jobsView } from "./views_media.js";
import { actionLabel } from "./subject_ui.js";

const toSubject = ({ params }) => { location.replace(`#/s/${params[0]}`); return { title: "" }; };
const toHome = () => { location.replace("#/"); return { title: "" }; };

const ROUTES = [
  [/^\/$/, home],
  [/^\/type\/([\w-]+)$/, typeList],
  [/^\/new\/([\w-]+)$/, newSubject],
  [/^\/s\/([\w-]+)$/, subject],
  [/^\/s\/([\w-]+)\/pic$/, ({ params, query }) => picture({ params: [params[0], null], query })],
  [/^\/s\/([\w-]+)\/step\/([\w-]+)$/, step],
  [/^\/s\/([\w-]+)\/step\/([\w-]+)\/pic$/, picture],
  [/^\/s\/([\w-]+)\/step\/([\w-]+)\/adjust$/, adjust],
  [/^\/s\/([\w-]+)\/step\/([\w-]+)\/do\/([\w-]+)$/, action],
  [/^\/s\/([\w-]+)\/(?:sec\/[\w-]+|prompts|ref|export|review|gen\/[\w-]+)$/, toSubject],
  [/^\/(?:still|preview)\/([\w-]+)$/, toSubject],
  [/^\/preview$/, toHome],
  [/^\/coverage$/, coverage],
  [/^\/jobs$/, jobsView],
  [/^\/job\/([a-f0-9]+)$/, jobView],
];

const view = document.getElementById("view");
const title = document.getElementById("title");
const back = document.getElementById("back");
let backTarget = "#/";
let renderSeq = 0;

async function render() {
  const seq = ++renderSeq;
  closeSheet();
  if (app.beforeLeave) { const f = app.beforeLeave; app.beforeLeave = null; try { await f(); } catch (e) { /* the screen shows its own error */ } }
  if (app.cleanup) { const f = app.cleanup; app.cleanup = null; f(); }
  const raw = location.hash.slice(1) || "/";
  const [path, qs] = raw.split("?");
  const query = Object.fromEntries(new URLSearchParams(qs || ""));
  let out;
  for (const [re, fn] of ROUTES) {
    const m = path.match(re);
    if (m) {
      try { out = await fn({ params: m.slice(1).map(decodeURIComponent), query }); }
      catch (e) { console.error(e); out = { title: "Error", node: errorBox({ error: e.message || String(e) }) }; }
      break;
    }
  }
  if (!out) out = { title: "Not found", node: errorBox({ error: `No screen for ${path}` }) };
  if (seq !== renderSeq) return;
  title.textContent = out.title || "Pipeline Studio";
  view.replaceChildren(out.node);
  backTarget = out.back || "#/";
  back.hidden = path === "/";
  for (const a of document.querySelectorAll(".tabs a")) a.classList.toggle("on", a.dataset.tab === (out.tab || ""));
  window.scrollTo(0, 0);
}

back.onclick = () => { location.hash = backTarget; };

function badges() {
  const act = jobs.active();
  const pill = document.getElementById("jobs-pill");
  pill.hidden = !act.length;
  pill.className = "pill spin";
  pill.textContent = act.length === 1 ? `${actionLabel(act[0].cmd).split(" ").slice(0, 3).join(" ")} ${Math.round(act[0].pct)}%` : `${act.length} running`;
  pill.onclick = () => { location.hash = act.length === 1 ? `#/job/${act[0].id}` : "#/jobs"; };
  const tp = document.getElementById("tab-pending");
  const pending = (app.subjects || []).reduce((n, s) => n + (s.pending || 0), 0);
  tp.hidden = !pending; tp.textContent = pending;
}

async function boot() {
  const res = await loadInfo();
  if (!res.ok) { view.replaceChildren(errorBox(res.data, h("details", { class: "small" }, h("summary", {}, "Details"), h("p", { class: "mono" }, "python tools/media.py studio")))); return; }
  document.getElementById("sim-banner").hidden = !app.info.simulated;
  await notify.setup();
  jobs.subscribe((job, finished) => { badges(); if (finished && job && job.subject && location.hash.startsWith(`#/s/${job.subject}`) && !location.hash.includes("/do/") && !location.hash.includes("/adjust")) render(); });
  window.addEventListener("hashchange", render);
  await render();
  await jobs.refresh();
  badges();
  setInterval(badges, 3000);
}

boot();
