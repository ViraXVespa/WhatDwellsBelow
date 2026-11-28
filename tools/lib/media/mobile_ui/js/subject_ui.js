// Shared pieces for the subject, step and picture screens: plain words, status chips,
// banners, picture thumbnails, and the one primary action a step offers.
import { fileUrl, get, post } from "./api.js";
import * as jobs from "./jobs.js";
import { app, go } from "./state.js";
import { basename, choose, h, showError, toast } from "./ui.js";

export const STATUS = { not_started: "Not started", in_progress: "In progress", needs_ok: "Needs your OK", done: "Done" };
export const PICTURE_STATE = { pending: "Waiting for your OK", approved: "Approved", rejected: "Rejected" };
export const VIEW_WORD = { front: "Front", side: "Side", back: "Back", other: "Other" };
const GUARDED = { female: ["edit", "body", "smooth"] };

export const actionLabel = (cmd) => (app.info.action_labels || {})[cmd] || cmd;
const UPPER = { ui: "UI", npc: "NPC", vfx: "VFX" };
export const human = (s) => UPPER[s] || String(s || "").replace(/[-_]+/g, " ").replace(/^\w/, (c) => c.toUpperCase());
export const subjectName = (id) => ((app.subjects || []).find((s) => s.id === id) || {}).name || human(id);
export const guarded = (sid) => GUARDED[sid] || [];

export async function loadSubject(id) { return get(`/subjects/${id}`); }

export function statusChip(step) {
  if (!step.available && step.status !== "done") return h("span", { class: "chip locked" }, "Locked");
  return h("span", { class: "chip st-" + step.status }, STATUS[step.status]);
}

export function thumb(still, sid, step) {
  const inner = still.kind === "mesh"
    ? [h("div", { class: "glbmark" }, "3D")]
    : [h("img", { src: fileUrl(still.path, still.mtime), alt: "picture", loading: "lazy" })];
  const where = step ? `#/s/${sid}/step/${step}/pic?path=${encodeURIComponent(still.path)}` : `#/s/${sid}/pic?path=${encodeURIComponent(still.path)}`;
  return h("a", { class: "thumb " + still.state, href: where, "aria-label": PICTURE_STATE[still.state] },
    ...inner,
    still.view ? h("span", { class: "view-tag" }, VIEW_WORD[still.view] || still.view) : null,
    h("span", { class: "tag badge " + still.state }, still.state === "pending" ? "Your OK" : PICTURE_STATE[still.state]));
}

// Banners: "needs a redo" (hard flags), "might need a look" (soft flags and changed earlier steps).
export function banners(doc, step, refresh) {
  const out = [];
  for (const reason of doc.dirty.hard) {
    out.push(h("div", { class: "banner redo" }, h("b", {}, "Needs a redo"), h("span", {}, ` because ${human(reason).toLowerCase()} changed.`),
      h("button", { class: "btn ghost small-btn", onclick: () => clearFlag(doc, "hard", reason, refresh) }, "Dismiss")));
  }
  for (const f of doc.dirty.soft) {
    out.push(h("div", { class: "banner look" }, h("b", {}, "Might need a look"), h("span", {}, ` because ${subjectName(f.source)} changed.`),
      h("button", { class: "btn ghost small-btn", onclick: () => clearFlag(doc, "soft", f.reason, refresh) }, "Dismiss")));
  }
  if (step && step.stale) {
    out.push(h("div", { class: "banner look" }, h("b", {}, "Might need a look"), h("span", {}, ` because ${step.stale_because} changed after this was approved.`)));
  }
  return out;
}

async function clearFlag(doc, kind, reason, refresh) {
  const ok = await choose("Dismiss this note?", "Only do this if nothing needs to change.", [{ label: "Dismiss", value: true, cls: "primary" }]);
  if (!ok) return;
  const res = await post(`/subjects/${doc.id}/clear`, { kind, reason });
  if (!res.ok) return showError(res);
  toast("Dismissed");
  refresh();
}

export function gateText(gate) {
  if (!gate || gate.ok) return null;
  return "Needs an approved " + gate.missing.map((m) => VIEW_WORD[m].toLowerCase()).join(" and ") + " picture first.";
}

// The one primary action for a step, from its status. Returns {label, run} or null.
export function primaryFor(data, step, nextStep) {
  const sid = data.subject.id;
  if (!step.available && step.status !== "done") return null;
  if (step.status === "done") {
    return nextStep ? { label: `Continue to ${nextStep.label}`, run: () => go(`#/s/${sid}/step/${nextStep.id}`) } : null;
  }
  if (step.job) return { label: "See progress", run: () => go(`#/job/${step.job}`) };
  const mine = data.stills.filter((s) => s.step === step.id);
  const pending = mine.filter((s) => s.state === "pending");
  const has = (cmd) => step.actions.includes(cmd) && !guarded(sid).includes(cmd);
  if (step.kind === "pictures") {
    if (pending.length) return { label: "Review pictures", run: () => go(`#/s/${sid}/step/${step.id}/pic?path=${encodeURIComponent(pending[0].path)}`) };
    const approvedMesh = mine.some((s) => s.kind === "mesh" && s.state === "approved");
    if (has("body") && data.gates.body.ok && !approvedMesh) return { label: actionLabel("body"), run: () => runAction(sid, step.id, "body", {}) };
    if (step.can_finish) return { label: "Approve this step", run: () => finishStep(sid, step) };
    if (has("smooth")) return { label: mine.length ? "Make new body pictures" : actionLabel("smooth"), run: () => runAction(sid, step.id, "smooth", {}) };
    if (has("tune")) return { label: actionLabel("tune"), run: () => go(`#/s/${sid}/step/${step.id}/do/tune`) };
    return null;
  }
  if (step.kind === "export") return null; // the export panel owns its button
  return { label: "Approve this step", run: () => finishStep(sid, step) };
}

export async function finishStep(sid, step, before) {
  if (before && !(await before())) return;
  const res = await post(`/subjects/${sid}/steps/${step.id}`, { action: "finish" });
  if (!res.ok) return showError(res);
  toast(`${step.label} approved`);
  const next = res.data.steps.find((s) => s.status !== "done");
  go(next ? `#/s/${sid}/step/${next.id}` : `#/s/${sid}`);
}

export async function reopenStep(sid, step) {
  const ok = await choose(`Reopen ${step.label}?`, "You can change it again. Steps after it stay approved and show a note to look at them again.",
    [{ label: "Reopen", value: true, cls: "primary" }]);
  if (!ok) return;
  const res = await post(`/subjects/${sid}/steps/${step.id}`, { action: "reopen" });
  if (!res.ok) return showError(res);
  toast(`${step.label} reopened`);
  window.dispatchEvent(new HashChangeEvent("hashchange"));
}

export async function runAction(sid, step, cmd, args) {
  const job = await jobs.start(cmd, sid, args, { step });
  if (job) go(`#/job/${job.id}`);
}

export function details(summary, ...kids) {
  return h("details", { class: "card details" }, h("summary", {}, summary), ...kids);
}

export function techRows(rows) {
  return h("dl", { class: "kv small" }, rows.filter(Boolean).map(([k, v]) => [h("dt", {}, k), h("dd", { class: "mono" }, typeof v === "object" ? JSON.stringify(v) : String(v))]));
}

export const pictureName = (still) => basename(still.path);
