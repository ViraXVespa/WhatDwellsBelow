// Job tracking. Jobs run on the PC; the page only polls. Started job ids are kept in localStorage,
// and the server registry lists every job, so a reload or a new tab picks running jobs up again.
import { get, post } from "./api.js";
import { choose, h, showError, toast } from "./ui.js";
import { app } from "./state.js";

const label = (cmd) => ((app.info && app.info.action_labels) || {})[cmd] || cmd;
import * as notify from "./notify.js";

const KEY = "wdb-studio-jobs";
const ACTIVE = new Set(["queued", "running"]);
const jobs = new Map();   // id -> job view (events merged)
const polling = new Set();
const listeners = new Set();

export const isActive = (job) => job && ACTIVE.has(job.status);
export const all = () => [...jobs.values()].sort((a, b) => b.created - a.created);
export const active = () => all().filter(isActive);
export const byId = (id) => jobs.get(id);

function tracked() { try { return JSON.parse(localStorage.getItem(KEY) || "[]"); } catch (e) { return []; } }
function track(id) {
  const ids = tracked().filter((x) => x !== id);
  ids.unshift(id);
  try { localStorage.setItem(KEY, JSON.stringify(ids.slice(0, 50))); } catch (e) { /* private mode */ }
}

export function subscribe(fn) { listeners.add(fn); return () => listeners.delete(fn); }
function emit(job, finished) { for (const fn of listeners) fn(job, finished); }

function merge(view) {
  const old = jobs.get(view.id);
  const events = old && old.events ? old.events.slice() : [];
  for (const e of view.events || []) if (!events.length || e.seq > events[events.length - 1].seq) events.push(e);
  const job = { ...(old || {}), ...view, events };
  jobs.set(job.id, job);
  return job;
}

export async function refresh() {
  const res = await get("/jobs");
  if (!res.ok) return;
  for (const row of res.data.jobs || []) {
    const old = jobs.get(row.id);
    const job = merge({ ...row, events: [] });
    if (old && isActive(old) && !isActive(job)) finished(job);
    if (isActive(job)) poll(job.id);
  }
  for (const id of tracked()) if (!jobs.has(id)) await load(id);
  emit(null, false);
}

export async function load(id) {
  const old = jobs.get(id);
  const res = await get(`/jobs/${id}?since=${old && old.events && old.events.length ? old.events[old.events.length - 1].seq : 0}`);
  if (!res.ok) return null;
  const job = merge(res.data);
  if (isActive(job)) poll(id);
  return job;
}

function finished(job) {
  const word = { done: "finished", failed: "did not pass", cancelled: "cancelled" }[job.status] || "stopped";
  toast(`${label(job.cmd)}: ${word}`, 3500);
  notify.jobFinished(job, `/#/job/${job.id}`);
  emit(job, true);
}

async function poll(id) {
  if (polling.has(id)) return;
  polling.add(id);
  try {
    for (;;) {
      const before = jobs.get(id);
      const since = before && before.events && before.events.length ? before.events[before.events.length - 1].seq : 0;
      const res = await get(`/jobs/${id}?since=${since}`);
      if (res.ok) {
        const job = merge(res.data);
        emit(job, false);
        if (!isActive(job)) { finished(job); break; }
      } else if (res.status === 404) break;
      await new Promise((r) => setTimeout(r, document.hidden ? 2500 : 900));
    }
  } finally { polling.delete(id); }
}

// Start a pipeline command. Handles the potentially-dirty prompt, a busy model slot and missing wiring.
export async function start(cmd, subject, args, opts = {}) {
  const send = (ack) => post("/jobs", { cmd, subject, step: opts.step, args, ack_soft: ack });
  let res = await send(!!opts.ackSoft);
  if (res.status === 409 && res.data.gate === "steps" && subject) {
    const goTo = await choose("Not yet", res.data.error, [{ label: "Go there", value: true, cls: "primary" }]);
    if (goTo) location.hash = `#/s/${subject}/step/${res.data.blocked_by}`;
    return null;
  }
  if (res.status === 409 && res.data.gate === "approvals") {
    await choose("Needs your OK first", res.data.error, [{ label: "OK", value: true, cls: "primary" }]);
    return null;
  }
  if (res.status === 409 && res.data.soft) {
    const list = h("ul", {}, res.data.soft.map((f) => h("li", {}, `${f.source.replace(/[-_]+/g, " ")} changed`)));
    const ok = await choose("Might need a look", h("div", {}, h("p", { class: "muted" }, "Something this depends on changed since it was last made. Doing this clears the note."), list),
      [{ label: "Do it anyway", value: true, cls: "primary" }]);
    if (!ok) return null;
    res = await send(true);
  }
  if (!res.ok) { showError(res); return null; }
  if (res.data.soft_note) toast("Cleared the might-need-a-look note.", 3500);
  track(res.data.id);
  const job = merge({ ...res.data, events: [] });
  emit(job, false);
  poll(job.id);
  return job;
}

export async function cancel(id) {
  const res = await post(`/jobs/${id}/cancel`);
  if (!res.ok) { showError(res); return false; }
  merge({ ...res.data, events: [] });
  toast("Cancel requested");
  return true;
}
