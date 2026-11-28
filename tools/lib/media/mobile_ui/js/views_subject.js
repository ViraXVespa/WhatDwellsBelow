// Subject overview and the step screen. A subject is a row of steps: Start, one per section,
// then Send to the game. Each step is Done only when you approve it, in order.
import { fileUrl, get, post } from "./api.js";
import * as jobs from "./jobs.js";
import { fieldsEditor, schemaEditor } from "./fields.js";
import { app, go, loadSubjects } from "./state.js";
import { closeSheet, errorBox, h, holdable, openSheet, showError, toast, when } from "./ui.js";
import {
  actionLabel, banners, details, finishStep, gateText, guarded, human, loadSubject, primaryFor, reopenStep,
  notReady, runAction, statusChip, STATUS, techRows, thumb,
} from "./subject_ui.js";

const refresh = () => window.dispatchEvent(new HashChangeEvent("hashchange"));
const typeWord = (t) => human(t).toLowerCase();
const sectionData = (doc, id) => ((doc.sections || {})[id] || {}).data || {};

function linkChip(link) {
  const chip = h("button", { class: "chip link" + (link.missing ? " hard" : "") }, `${human(link.rel)}: ${link.name || human(link.id)}`);
  return holdable(chip, () => openSheet(
    h("h2", {}, link.name || human(link.id)),
    h("p", { class: "muted" }, `${human(link.rel)} - ${link.type ? typeWord(link.type) : "missing"}`),
    h("div", { class: "list" },
      h("button", { class: "btn primary full", disabled: link.missing, onclick: () => { closeSheet(); go(`#/s/${link.id}`); } }, "Open it"),
      h("button", { class: "btn ghost full", onclick: closeSheet }, "Close")),
  ), () => { if (!link.missing) go(`#/s/${link.id}`); });
}

function stepRow(sid, s, i) {
  const locked = !s.available && s.status !== "done";
  return h("a", { class: "item step-row" + (locked ? " locked" : ""), href: `#/s/${sid}/step/${s.id}` },
    h("span", { class: "num st-" + (locked ? "locked" : s.status) }, s.status === "done" ? "✓" : String(i + 1)),
    h("div", { class: "grow" }, h("b", {}, s.label),
      h("small", {}, locked ? `Finish ${s.blocked_by_label} first` : s.stale ? "Might need a look" : s.pending ? `${s.pending} picture${s.pending === 1 ? "" : "s"} waiting` : "")),
    s.job ? h("span", { class: "badge running" }, "Working") : statusChip(s));
}

// ---- overview ----------------------------------------------------------------------
export async function subject({ params }) {
  const sid = params[0];
  const res = await loadSubject(sid);
  if (!res.ok) return { title: "Not found", node: errorBox(res.data), back: "#/" };
  if (!app.subjects) await loadSubjects();
  const { subject: doc, links, stills, steps } = res.data;
  const done = steps.filter((s) => s.status === "done").length;
  const current = steps.find((s) => s.status !== "done");
  const unsorted = stills.filter((s) => !s.step);
  const linkTo = h("select", {}, h("option", { value: "" }, "Pick one"), (app.subjects || []).filter((s) => s.id !== sid).map((s) => h("option", { value: s.id }, `${s.name} (${typeWord(s.type)})`)));
  const rel = h("input", { type: "text", placeholder: "How they connect, e.g. wears, drops, talks to" });
  const addLink = async () => {
    if (!linkTo.value || !rel.value.trim()) return toast("Pick one and say how they connect");
    const r = await post(`/subjects/${sid}/links`, { rel: rel.value.trim(), to: linkTo.value });
    if (!r.ok) return showError(r);
    toast("Connected"); refresh();
  };
  const recent = jobs.all().filter((j) => j.subject === sid).slice(0, 5);
  const node = h("div", {},
    h("div", { class: "card" },
      h("div", { class: "row between" }, h("b", {}, human(doc.type)), h("span", { class: "small muted" }, `${done} of ${steps.length} steps done`)),
      h("div", { class: "bar", style: { marginTop: "8px" } }, h("div", { style: { width: `${Math.round((100 * done) / steps.length)}%` } })),
      current ? h("a", { class: "btn primary full", style: { marginTop: "12px" }, href: `#/s/${sid}/step/${current.id}` }, `Continue: ${current.label}`)
        : h("p", { class: "ok-text" }, "Every step is done.")),
    banners(doc, null, refresh),
    h("h3", {}, "Steps"),
    h("div", { class: "list" }, steps.map((s, i) => stepRow(sid, s, i))),
    unsorted.length ? [h("h3", {}, "Pictures not on a step yet"), h("p", { class: "small muted" }, "Open one to put it on a step."),
      h("div", { class: "thumbs" }, unsorted.map((s) => thumb(s, sid, null)))] : null,
    h("h3", {}, "Connected to"),
    links.length ? h("div", { class: "row" }, links.map(linkChip)) : h("p", { class: "muted" }, "Nothing yet."),
    h("details", { class: "card" }, h("summary", {}, "Connect to something"), h("label", { class: "field" }, h("span", {}, "What"), linkTo),
      h("label", { class: "field" }, h("span", {}, "How"), rel), h("button", { class: "btn full", onclick: addLink }, "Connect")),
    recent.length ? [h("h3", {}, "Recent work"), h("div", { class: "list" }, recent.map((j) => h("a", { class: "item", href: `#/job/${j.id}` },
      h("div", { class: "grow" }, h("b", {}, actionLabel(j.cmd)), h("small", {}, when(j.created))), h("span", { class: "badge " + j.status }, jobWord(j.status)))))] : null,
    details("Details", techRows([["id", doc.id], ["type", doc.type], ["file", `${app.info.store_root}/${doc.type}/${doc.id}.json`],
      ["sent to the game", doc.exported_at || "never"], ["redo flags", doc.dirty.hard], ["look flags", doc.dirty.soft.map((f) => `${f.source}:${f.reason}`)]])));
  return { title: doc.name, node, back: `#/type/${doc.type}`, tab: "home" };
}

export const jobWord = (s) => ({ queued: "Waiting", running: "Working", done: "Done", failed: "Did not pass", error: "Stopped", cancelled: "Cancelled", lost: "Stopped" }[s] || s);

// ---- step screen -------------------------------------------------------------------
export async function step({ params }) {
  const [sid, stepId] = params;
  const res = await loadSubject(sid);
  if (!res.ok) return { title: "Not found", node: errorBox(res.data), back: "#/" };
  const data = res.data;
  const { subject: doc, steps } = data;
  const idx = steps.findIndex((s) => s.id === stepId);
  if (idx < 0) return { title: doc.name, node: errorBox({ error: "This step is not part of this subject." }), back: `#/s/${sid}` };
  const s = steps[idx];
  const next = steps[idx + 1];
  const locked = !s.available && s.status !== "done";
  const readOnly = s.status === "done";
  const head = h("div", { class: "step-head" },
    h("div", { class: "row between" }, h("span", { class: "small muted" }, `Step ${idx + 1} of ${steps.length}`), s.job ? h("span", { class: "badge running" }, "Working") : statusChip(s)),
    h("div", { class: "dots" }, steps.map((x, i) => h("a", { class: "dot st-" + (!x.available && x.status !== "done" ? "locked" : x.status) + (i === idx ? " here" : ""), href: `#/s/${sid}/step/${x.id}`, "aria-label": x.label }))));
  if (locked) {
    const node = h("div", {}, head,
      h("div", { class: "card locked-card" }, h("b", {}, `Finish ${s.blocked_by_label} first`),
        h("p", { class: "muted" }, "Steps are approved in order. This one opens when every step before it is done."),
        h("a", { class: "btn primary full", href: `#/s/${sid}/step/${s.blocked_by}` }, `Go to ${s.blocked_by_label}`)));
    return { title: `${doc.name}: ${s.label}`, node, back: `#/s/${sid}`, tab: "home" };
  }

  let body, beforeFinish = null;
  if (s.kind === "start") body = startPanel(data, s);
  else if (s.kind === "export") body = exportPanel(data, s);
  if (s.kind === "fields" || s.kind === "pictures") {
    const ed = sectionEditor(doc, s, readOnly);
    beforeFinish = ed.save;
    body = [s.open_question ? h("div", { class: "note-box small" }, h("b", {}, "Still to decide: "), s.open_question, " Write notes here for now.") : null,
      s.kind === "pictures" || data.stills.some((x) => x.step === s.id) ? picturesPanel(data, s, readOnly) : null, ed.node];
  }

  const primary = primaryFor(data, s, next);
  const primaryBtn = primary ? h("button", { class: "btn primary full", onclick: async () => {
    if (primary.label === "Approve this step") return finishStep(sid, s, beforeFinish);
    primary.run();
  } }, primary.label) : null;

  const more = [];
  if (!readOnly) {
    for (const cmd of s.actions) {
      if (guarded(sid).includes(cmd) || cmd === "export") continue;
      if (primary && primary.label === actionLabel(cmd)) continue;
      const gate = (cmd === "body" || cmd === "mesh") ? data.gates[cmd] : null;
      const off = notReady(s, cmd);
      more.push(h("a", { class: "item" + (gate && !gate.ok ? " disabled" : ""), href: gate && !gate.ok ? undefined : `#/s/${sid}/step/${s.id}/do/${cmd}` },
        h("div", { class: "grow" }, h("b", {}, actionLabel(cmd)), !off && gate && !gate.ok ? h("small", {}, gateText(gate)) : null),
        off ? h("span", { class: "chip locked" }, "Not set up yet") : null));
    }
    if (PROMPTED.some((a) => s.actions.includes(a))) more.push(h("a", { class: "item", href: `#/s/${sid}/step/${s.id}/adjust` }, h("div", { class: "grow" }, h("b", {}, "Adjust how pictures are made"),
      Object.keys(data.overrides[s.id] || {}).length > 1 ? h("small", {}, "Adjusted for this step") : null)));
    if (s.kind !== "export" && s.kind !== "start" && primary?.label !== "Approve this step") {
      more.push(h("button", { class: "item", onclick: () => finishStep(sid, s, beforeFinish), disabled: !s.can_finish && s.finish_blocker !== "fields" && s.finish_blocker !== "empty" },
        h("div", { class: "grow" }, h("b", {}, "Approve this step"), !s.can_finish && s.finish_message ? h("small", {}, s.finish_message) : null)));
    }
  } else if (s.available) {
    more.push(h("button", { class: "item", onclick: () => reopenStep(sid, s) }, h("div", { class: "grow" }, h("b", {}, s.id === "export" ? "Reopen to send again" : "Reopen this step"),
      h("small", {}, "Lets you change it again."))));
  }

  const node = h("div", {}, head,
    banners(doc, s, refresh),
    readOnly ? h("div", { class: "note-box small" }, `Approved ${when(s.done_at)}. Reopen it to change it.`) : null,
    primaryBtn,
    !readOnly && s.available && TUNABLE.some((a) => s.actions.includes(a)) ? autotuneRow(sid, s) : null,
    more.length ? h("details", { class: "card more" }, h("summary", {}, "More actions"), h("div", { class: "list" }, more)) : null,
    body,
    next ? h("a", { class: "btn ghost full", href: `#/s/${sid}/step/${next.id}`, style: { marginTop: "12px" } }, `Next: ${next.label}`) : null,
    details("Details", techRows([["step", s.id], ["kind", s.kind], ["actions", s.actions.join(", ") || "-"], ["not set up", (s.not_ready || []).join(", ") || "-"], ["status", s.status],
      ["approved", s.done_at || "-"], ["section data", s.kind === "start" || s.kind === "export" ? "-" : sectionData(doc, s.id)]])));
  return { title: `${doc.name}: ${s.label}`, node, back: `#/s/${sid}`, tab: "home" };
}

const PROMPTED = ["generate", "tune", "smooth", "body", "edit", "variant", "icon", "tile"];
const TUNABLE = ["generate", "variant", "icon", "tile"];

function autotuneRow(sid, s) {
  const box = h("input", { type: "checkbox" });
  box.checked = !!s.autotune;
  box.onchange = async () => {
    const r = await post(`/subjects/${sid}/steps/${s.id}`, { action: "autotune", on: box.checked });
    if (!r.ok) { box.checked = !box.checked; return showError(r); }
    toast(box.checked ? "Auto-tune is on for this step" : "Auto-tune is off for this step");
  };
  return h("label", { class: "check card" }, box, h("span", {}, h("b", {}, "Auto-tune new pictures"),
    h("small", { class: "help" }, " Checks each new picture and retries until it passes. Off: pictures come straight to you.")));
}

function sectionEditor(doc, s, readOnly) {
  const sid = doc.id;
  const nameIn = h("input", { type: "text", value: doc.name, disabled: readOnly });
  let lastSaved = JSON.stringify({ d: sectionData(doc, s.id), n: doc.name });
  const err = h("div");
  let saving = false;
  async function save() {
    if (readOnly) return true;
    const next = ed.read();
    const body = { data: next };
    if (s.id === "details") {
      if (!nameIn.value.trim()) { err.replaceChildren(errorBox({ error: "Give it a name first." })); return false; }
      body.name = nameIn.value.trim();
    }
    const snap = JSON.stringify({ d: next, n: body.name || doc.name });
    if (snap === lastSaved) return true;
    if (saving) return false;
    saving = true;
    const r = await post(`/subjects/${sid}/sections/${s.id}`, body);
    saving = false;
    if (!r.ok) { err.replaceChildren(errorBox(r.data)); return false; }
    err.replaceChildren(); lastSaved = snap; ed.syncRaw();
    toast("Saved");
    if (r.data.flagged && r.data.flagged.length) toast(`Connected things might need a look: ${r.data.flagged.map((f) => f.name || human(f.id)).join(", ")}`, 4000);
    return true;
  }
  const ed = (s.fields || []).length ? schemaEditor(s.fields, sectionData(doc, s.id), { readOnly, onChange: () => save() })
    : fieldsEditor(sectionData(doc, s.id), { readOnly, onChange: () => save() });
  if (!readOnly) {
    app.beforeLeave = save;
    const onHide = () => { if (document.hidden) save(); };
    document.addEventListener("visibilitychange", onHide);
    app.cleanup = () => document.removeEventListener("visibilitychange", onHide);
    if (s.id === "details") nameIn.addEventListener("change", save);
  }
  const node = h("div", {},
    s.kind === "pictures" ? h("h3", {}, "What the game needs") : null,
    s.id === "details" ? h("label", { class: "field" }, h("span", {}, "Name"), nameIn) : null,
    ed.node, err,
    h("details", { class: "card details" }, h("summary", {}, "Edit as text"), ed.details),
    readOnly ? null : h("p", { class: "small muted" }, "Changes save on their own."));
  return { node, save };
}

function picturesPanel(data, s, readOnly) {
  const sid = data.subject.id;
  const mine = data.stills.filter((x) => x.step === s.id);
  const group = (state, title) => {
    const rows = mine.filter((x) => x.state === state);
    if (!rows.length) return null;
    const grid = h("div", { class: "thumbs" }, rows.map((x) => thumb(x, sid, s.id)));
    return state === "hidden" ? h("details", { class: "card" }, h("summary", {}, `${title} (${rows.length})`), grid) : [h("h3", {}, `${title} (${rows.length})`), grid];
  };
  const checks = data.reviews.filter((r) => mine.some((m) => m.path === r.image || (r.image && m.path.endsWith(r.image))));
  const gate = s.actions.includes("body") ? data.gates.body : null;
  return h("div", {},
    gate && !gate.ok && !readOnly ? h("div", { class: "note-box small" }, "To build the 3D body: " + gateText(gate)) : null,
    mine.length ? [group("pending", "Waiting for your OK"), group("approved", "Approved"), group("rejected", "Rejected"), group("hidden", "Hidden")]
      : h("p", { class: "muted" }, s.needs.includes("clips") ? "No animations on this step yet." : "No pictures on this step yet."),
    checks.length ? h("details", { class: "card" }, h("summary", {}, `Check results (${checks.length})`), checks.map(checkCard)) : null);
}

export function checkCard(r) {
  const failed = r.checks.filter((c) => c.pass === false || c.ok === false || c.result === "fail");
  return h("div", { class: "check-card" },
    h("b", {}, failed.length ? `${failed.length} of ${r.checks.length} checks did not pass` : `All ${r.checks.length} checks passed`),
    failed.length ? h("ul", { class: "small" }, failed.map((c) => h("li", {}, c.note || c.why || c.text || c.check || c.id || "a check"))) : null);
}

function startPanel(data, s) {
  const doc = data.subject;
  const sid = doc.id;
  const ref = (doc.studio || {}).reference;
  const ing = ref && ref.ingest;
  if (s.status === "done") {
    return h("div", { class: "card" }, ref ? h("p", {}, "Started from a reference picture.") : h("p", {}, "Started without a reference picture."),
      ref && ref.path ? h("img", { class: "big-img", src: fileUrl(ref.path) }) : null);
  }
  let mode = "upload";
  const err = h("div");
  const file = h("input", { type: "file", accept: "image/png,image/jpeg,image/webp" });
  const url = h("input", { type: "url" });
  const box = h("div");
  const seg = h("div", { class: "seg" });
  const modes = [["upload", "From this phone"], ["url", "Picture link"], ["post", "X post"]];
  const draw = () => {
    seg.replaceChildren(...modes.map(([m, l]) => h("button", { class: m === mode ? "on" : "", onclick: () => { mode = m; draw(); } }, l)));
    url.placeholder = mode === "post" ? "https://x.com/NAME/status/ID" : "https://.../picture.png";
    box.replaceChildren(mode === "upload" ? file : url);
  };
  draw();
  const store = async () => {
    let payload;
    if (mode === "upload") {
      const f = file.files[0];
      if (!f) return toast("Pick a picture");
      const b64 = await new Promise((ok, bad) => { const r = new FileReader(); r.onload = () => ok(String(r.result).split(",")[1]); r.onerror = bad; r.readAsDataURL(f); });
      payload = { kind: "upload", filename: f.name, data: b64 };
    } else payload = { kind: mode, value: url.value.trim() };
    const r = await post(`/subjects/${sid}/reference`, payload);
    if (!r.ok) return err.replaceChildren(errorBox(r.data));
    toast("Reference saved"); refresh();
  };
  return h("div", {},
    ref ? h("div", { class: "card" }, h("b", {}, "Reference picture"), ref.path ? h("img", { class: "big-img", src: fileUrl(ref.path) }) : h("p", { class: "muted" }, "Saved as a link."),
      h("button", { class: (ing ? "btn" : "btn primary") + " full", onclick: () => runAction(sid, "start", "reference", {}) }, ing ? "Read it again" : actionLabel("reference"))) : null,
    ing ? h("div", { class: "card" }, h("b", {}, "What it shows"), h("p", {}, ing.description),
      ing.mannequin && ing.mannequin.length ? [h("b", {}, "Body"), h("ul", {}, ing.mannequin.map((m) => h("li", {}, m)))] : null,
      ing.traits && ing.traits.length ? [h("b", {}, "Look"), h("ul", {}, ing.traits.map((m) => h("li", {}, m)))] : null) : null,
    h("details", { class: "card", open: !ref }, h("summary", {}, ref ? "Use a different reference" : "Add a reference picture (optional)"),
      seg, h("div", { style: { height: "8px" } }), box, err, h("button", { class: "btn full", style: { marginTop: "8px" }, onclick: store }, "Save the reference")),
    h("p", { class: "small muted" }, "No reference? Approve this step to start from the steps that follow."));
}

function exportPanel(data, s) {
  const doc = data.subject;
  const sid = doc.id;
  if (s.status === "done") return h("div", { class: "card" }, h("p", { class: "ok-text" }, `Sent to the game ${when(doc.exported_at || s.done_at)}.`));
  const sections = data.steps.filter((x) => !["start", "export"].includes(x.id));
  const bypass = h("input", { type: "checkbox" });
  const hard = doc.dirty.hard;
  const err = h("div");
  const send = async () => {
    if (hard.length && !bypass.checked) return err.replaceChildren(errorBox({ error: "Something needs a redo. Redo it, or tick “Send anyway”." }));
    const job = await jobs.start("export", sid, { areas: sections.map((x) => x.id), bypass: bypass.checked }, { step: "export" });
    if (job) go(`#/job/${job.id}`);
  };
  return h("div", {},
    h("div", { class: "card" }, h("b", {}, "What goes to the game"), h("ul", {}, sections.map((x) => h("li", {}, x.label)))),
    hard.length ? h("div", { class: "card" }, h("label", { class: "check" }, bypass, h("span", {}, "Send anyway, even though something needs a redo"))) : null,
    err,
    h("button", { class: "btn primary full", onclick: send }, actionLabel("export")),
    h("p", { class: "small muted" }, app.info.simulated ? "Practice mode: the game files do not change." : "This updates the game's copy of this subject."));
}

