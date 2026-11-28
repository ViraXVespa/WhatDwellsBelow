// Subject record, section editor with local save + review, prompts, start-from-reference, export.
import { fileUrl, get, post } from "./api.js";
import * as jobs from "./jobs.js";
import { app, command, go, sectionsOf } from "./state.js";
import { basename, cap, choose, errorBox, h, holdable, openSheet, closeSheet, showError, toast, when } from "./ui.js";

export async function loadSubject(id) {
  const res = await get(`/subjects/${id}`);
  return res;
}

const GEN_ORDER = ["tune", "review", "correct", "frame", "proportion", "mesh", "smooth", "body", "edit"];
const GUARDED = { female: ["edit", "body", "smooth"] };

export function thumb(still, sid, onTap) {
  const cls = "thumb " + still.state;
  const inner = still.kind === "mesh"
    ? [h("div", { class: "glbmark" }, "3D")]
    : [h("img", { src: fileUrl(still.path, still.mtime), alt: basename(still.path), loading: "lazy" })];
  return h("div", { class: cls, title: basename(still.path), onclick: onTap || (() => go(`#/still/${sid}?path=${encodeURIComponent(still.path)}`)) },
    ...inner,
    still.view ? h("span", { class: "view-tag" }, still.view) : null,
    h("span", { class: "tag badge " + still.state }, still.simulated ? "sim " + still.state : still.state));
}

export function gateNote(gates, cmd, sid) {
  const g = gates && gates[cmd];
  if (!g || g.ok) return null;
  const missing = g.missing || [];
  let msg;
  if (cmd === "export") {
    const n = missing.length;
    const sent = missing.filter((m) => m.state === "rejected").length;
    msg = n === 1 ? "One picture still needs your OK before export." : `${n} pictures still need your OK before export.`;
    if (sent) msg += " Sent-back pictures need a new version first.";
  } else {
    msg = "Needs an approved " + missing.join(" and ") + " picture first.";
  }
  return h("p", { class: "note-box small" }, msg, " ", h("a", { href: `#/preview/${sid}` }, "Open the approval queue"));
}

function flagChips(doc, refresh) {
  const hard = doc.dirty.hard.map((r) => h("button", { class: "chip hard", onclick: () => flagSheet(doc, "hard", r, refresh) }, "hard: " + r));
  const soft = doc.dirty.soft.map((f) => h("button", { class: "chip soft", onclick: () => flagSheet(doc, "soft", f.reason, refresh, f) }, "maybe dirty: " + f.reason));
  return hard.length || soft.length ? h("div", { class: "row" }, hard, soft) : h("span", { class: "chip ok" }, "clean");
}

async function flagSheet(doc, kind, reason, refresh, flag) {
  const text = kind === "hard"
    ? "A hard flag holds export until it is resolved (regenerate) or bypassed."
    : `Potentially dirty: ${flag.source} changed (${when(flag.at)}). It is shown again, then cleared, the next time you regenerate.`;
  const pick = await choose(kind === "hard" ? `Hard: ${reason}` : `Maybe dirty: ${reason}`, text, [
    { label: "Regenerate...", value: "gen", cls: "primary" },
    { label: "Clear this flag", value: "clear" },
  ]);
  if (pick === "gen") go(`#/s/${doc.id}/gen/tune`);
  if (pick === "clear") {
    const res = await post(`/subjects/${doc.id}/clear`, { kind, reason });
    if (!res.ok) return showError(res);
    toast("Flag cleared");
    refresh();
  }
}

function linkChip(link) {
  const label = `${link.rel}: ${link.name || link.id}`;
  const chip = h("button", { class: "chip link" + (link.missing ? " hard" : "") }, label);
  return holdable(chip, () => openSheet(
    h("h2", {}, link.name || link.id),
    h("p", { class: "muted" }, `${link.type || "missing"} - ${link.id} - ${link.rel}`),
    h("div", { class: "list" },
      h("button", { class: "btn primary full", onclick: () => { closeSheet(); go(`#/s/${link.id}`); }, disabled: link.missing }, `Edit this ${link.type || "subject"}`),
      h("button", { class: "btn full", onclick: () => { closeSheet(); go(`#/preview/${link.id}`); }, disabled: link.missing }, "Open its preview"),
      h("button", { class: "btn ghost full", onclick: closeSheet }, "Close")),
  ), () => { if (!link.missing) go(`#/s/${link.id}`); });
}

export async function subject({ params }) {
  const sid = params[0];
  const res = await loadSubject(sid);
  if (!res.ok) return { title: sid, node: errorBox(res.data), back: "#/" };
  const { subject: doc, links, stills, reviews, gates = {} } = res.data;
  const ui = doc.studio || {};
  const refresh = () => window.dispatchEvent(new HashChangeEvent("hashchange"));
  const edited = ui.edited || {};
  const sections = sectionsOf(doc.type);
  const guarded = GUARDED[sid] || [];

  const linkTo = h("select", {}, h("option", { value: "" }, "Link to..."), (app.subjects || []).filter((s) => s.id !== sid).map((s) => h("option", { value: s.id }, `${s.name} (${s.type})`)));
  const rel = h("input", { type: "text", placeholder: "relation, e.g. wears, drops, talks" });
  const addLink = h("button", { class: "btn", onclick: async () => {
    if (!linkTo.value || !rel.value.trim()) return toast("Pick a subject and a relation");
    const r = await post(`/subjects/${sid}/links`, { rel: rel.value.trim(), to: linkTo.value });
    if (!r.ok) return showError(r);
    toast("Linked"); refresh();
  } }, "Add link");
  if (!app.subjects) get("/subjects").then((r) => { if (r.ok) { app.subjects = r.data.subjects; linkTo.append(...r.data.subjects.filter((s) => s.id !== sid).map((s) => h("option", { value: s.id }, `${s.name} (${s.type})`))); } });

  const ref = ui.reference;
  const latest = reviews[0];
  const myJobs = jobs.all().filter((j) => j.subject === sid).slice(0, 4);
  const node = h("div", {},
    h("div", { class: "card" },
      h("div", { class: "row between" }, h("div", {}, h("b", { style: { fontSize: "18px" } }, doc.name), h("div", { class: "small muted mono" }, `${doc.type} - ${doc.id}`)),
        h("a", { class: "btn", href: `#/s/${sid}/export` }, "Export")),
      h("dl", { class: "kv", style: { marginTop: "8px" } },
        doc.template_of ? [h("dt", {}, "template"), h("dd", {}, doc.template_of)] : null,
        h("dt", {}, "draw scale"), h("dd", {}, String(doc.draw_scale)),
        h("dt", {}, "exported"), h("dd", {}, doc.exported_at ? when(doc.exported_at) : "never"),
        h("dt", {}, "flags"), h("dd", {}, flagChips(doc, refresh)))),
    h("h3", {}, "Sections"),
    h("div", { class: "grid" }, sections.map((s) => h("a", { class: "tile", href: `#/s/${sid}/sec/${s.id}` },
      h("b", {}, cap(s.id)),
      h("span", { class: "meta" }, s.skeleton ? h("span", { class: "badge skeleton" }, "skeleton") : `${Object.keys((doc.sections[s.id] || {}).data || {}).length} fields`),
      h("span", { class: "meta" }, edited[s.id] ? "edited " + when(edited[s.id]) : "")))),
    h("div", { class: "btn-row" }, h("a", { class: "btn", href: `#/s/${sid}/prompts` }, "Prompts"), h("a", { class: "btn", href: `#/s/${sid}/ref` }, ref ? "Reference" : "Start from reference")),
    ref ? h("div", { class: "card small" }, h("b", {}, "Reference: "), ref.url || ref.path, ref.ingest ? h("div", { class: "muted" }, ref.ingest.description) : null) : null,
    h("h3", {}, "Generate"),
    h("a", { class: "btn primary full", href: `#/s/${sid}/gen/tune` }, "Auto-tune to the locked artstyle"),
    h("div", { class: "btn-row" }, GEN_ORDER.filter((c) => c !== "tune" && !guarded.includes(c)).map((c) => {
      const blocked = (c === "body" || c === "mesh") && gates[c] && !gates[c].ok;
      return blocked
        ? h("button", { class: "btn", disabled: true, title: "Needs an approved front and side picture first" }, command(c) ? command(c).label : c)
        : h("a", { class: "btn", href: `#/s/${sid}/gen/${c}` }, command(c) ? command(c).label : c);
    })),
    gateNote(gates, "body", sid) || gateNote(gates, "mesh", sid),
    guarded.length ? h("p", { class: "small muted" }, `${guarded.join(", ")} stay off for ${sid} in the studio.`) : null,
    h("div", { class: "row between" }, h("h3", {}, `Stills and meshes (${stills.length})`), h("a", { href: `#/preview/${sid}` }, "Preview all")),
    stills.length ? h("div", { class: "thumbs" }, stills.slice(0, 9).map((s) => thumb(s, sid))) : h("p", { class: "muted" }, "Nothing generated yet."),
    h("div", { class: "row between" }, h("h3", {}, "Review"), h("a", { href: `#/s/${sid}/review` }, "Open")),
    latest ? h("a", { class: "item", href: `#/s/${sid}/review` }, h("div", { class: "grow" }, h("b", {}, latest.role), h("small", {}, `${basename(latest.path)} - ${when(latest.mtime)}`)),
      h("span", { class: "badge " + latest.verdict }, latest.verdict)) : h("p", { class: "muted" }, "No review yet."),
    h("h3", {}, "Links (hold to jump)"),
    links.length ? h("div", { class: "row" }, links.map(linkChip)) : h("p", { class: "muted" }, "No links."),
    h("div", { class: "card" }, h("label", { class: "field" }, h("span", {}, "New link"), rel), linkTo, h("div", { style: { height: "8px" } }), addLink),
    myJobs.length ? [h("h3", {}, "Recent jobs"), h("div", { class: "list" }, myJobs.map(jobRow))] : null);
  return { title: doc.name, node, back: `#/type/${doc.type}`, tab: "home" };
}

export function jobRow(j) {
  return h("a", { class: "item", href: `#/job/${j.id}` },
    h("div", { class: "grow" }, h("b", {}, j.cmd), h("small", {}, `${j.subject || "-"} - ${j.stage || ""} - ${when(j.created)}`)),
    j.simulated ? h("span", { class: "chip sim" }, "sim") : null,
    h("span", { class: "badge " + j.status }, jobs.isActive(j) ? `${j.status} ${Math.round(j.pct)}%` : j.status));
}

// ---- section editor ---------------------------------------------------------------
function fieldFor(key, value, onChange) {
  let input, read;
  if (typeof value === "boolean") {
    input = h("input", { type: "checkbox" }); input.checked = value; read = () => input.checked;
    return { el: h("label", { class: "check" }, input, h("span", {}, key)), read, input };
  }
  if (typeof value === "number") { input = h("input", { type: "number", step: "any", value: String(value) }); read = () => (input.value === "" ? null : Number(input.value)); }
  else if (typeof value === "string") {
    input = value.length > 60 || value.includes("\n") ? h("textarea", {}) : h("input", { type: "text" });
    input.value = value; read = () => input.value;
  } else {
    input = h("textarea", { class: "json" }); input.value = JSON.stringify(value, null, 2);
    read = () => JSON.parse(input.value || "null");
  }
  return { el: h("label", { class: "field" }, h("span", {}, key), input), read, input };
}

export async function section({ params, query }) {
  const [sid, sec] = params;
  const res = await loadSubject(sid);
  if (!res.ok) return { title: sid, node: errorBox(res.data) };
  const doc = res.data.subject;
  const meta = sectionsOf(doc.type).find((s) => s.id === sec);
  if (!doc.sections[sec]) return { title: sec, node: errorBox({ error: `No section ${sec} on ${doc.type}` }) };
  let data = JSON.parse(JSON.stringify(doc.sections[sec].data || {}));
  const original = JSON.stringify({ data, name: doc.name });
  let raw = false;
  const formEl = h("div");
  const err = h("div");
  const nameIn = h("input", { type: "text", value: doc.name });
  let fields = [];

  function collect() {
    if (raw) return JSON.parse(rawIn.value || "{}");
    const out = {};
    for (const f of fields) out[f.key] = f.read();
    return out;
  }
  const rawIn = h("textarea", { class: "json", style: { minHeight: "260px" } });
  function draw() {
    fields = Object.entries(data).map(([k, v]) => ({ key: k, ...fieldFor(k, v) }));
    for (const f of fields) f.input.addEventListener("change", autosave);
    rawIn.value = JSON.stringify(data, null, 2);
    formEl.replaceChildren(...(raw ? [rawIn] : fields.length ? fields.map((f) => f.el) : [h("p", { class: "muted" }, meta && meta.skeleton ? "A skeleton section: a navigation shell, empty on purpose until real examples fill it." : "No fields yet. Add one below.")]));
  }
  draw();
  rawIn.addEventListener("change", autosave);

  const newKey = h("input", { type: "text", placeholder: "field name" });
  const newType = h("select", {}, ["text", "number", "yes/no", "list", "JSON object"].map((t) => h("option", { value: t }, t)));
  const addField = () => {
    const k = newKey.value.trim();
    if (!k) return toast("Name the field");
    try { data = collect(); } catch (e) { return err.replaceChildren(errorBox({ error: "Fix the JSON first: " + e.message })); }
    if (k in data) return toast("That field exists");
    data[k] = { text: "", number: 0, "yes/no": false, list: [], "JSON object": {} }[newType.value];
    newKey.value = ""; draw();
  };

  let saving = false, lastSaved = original;
  async function save(showReview) {
    let next;
    try { next = collect(); } catch (e) { err.replaceChildren(errorBox({ error: "Not saved: the JSON does not parse (" + e.message + ")" })); return false; }
    const body = { data: next };
    if (sec === "details") {
      if (!nameIn.value.trim()) { err.replaceChildren(errorBox({ error: "A name is required." })); return false; }
      body.name = nameIn.value.trim();
    }
    const snapshot = JSON.stringify({ data: next, name: body.name || doc.name });
    if (snapshot === lastSaved && !showReview) return true;
    if (saving) return false;
    saving = true;
    const r = await post(`/subjects/${sid}/sections/${sec}`, body);
    saving = false;
    if (!r.ok) { err.replaceChildren(errorBox(r.data)); return false; }
    err.replaceChildren();
    const before = JSON.parse(lastSaved);
    lastSaved = snapshot; data = next;
    if (showReview) reviewSheet(r.data, before.data, next);
    else toast("Autosaved locally");
    return true;
  }
  async function autosave() { await save(false); }
  app.beforeLeave = () => save(false);
  const onHide = () => { if (document.hidden) save(false); };
  document.addEventListener("visibilitychange", onHide);
  app.cleanup = () => document.removeEventListener("visibilitychange", onHide);

  function reviewSheet(result, before, after) {
    const keys = [...new Set([...Object.keys(before || {}), ...Object.keys(after)])];
    const changed = keys.filter((k) => JSON.stringify((before || {})[k]) !== JSON.stringify(after[k]));
    const order = sectionsOf(doc.type).map((s) => s.id);
    const next = order[order.indexOf(sec) + 1];
    openSheet(
      h("h2", {}, "Review: " + cap(sec)),
      h("p", { class: "muted small" }, "Saved locally to the WIP store. The game does not change until you export."),
      changed.length ? h("div", { class: "list" }, changed.map((k) => h("div", { class: "item" }, h("div", { class: "grow" }, h("b", {}, k),
        h("small", { class: "mono" }, `${JSON.stringify((before || {})[k]) ?? "(new)"} -> ${JSON.stringify(after[k]) ?? "(removed)"}`))))) : h("p", { class: "muted" }, "No field changed."),
      result.flagged && result.flagged.length ? h("div", { class: "note-box" }, h("b", {}, "Linked subjects flagged potentially dirty: "), result.flagged.map((f) => f.id).join(", ")) : null,
      result.subject.dirty.hard.length ? h("div", { class: "error-box" }, "Hard flags on this subject: " + result.subject.dirty.hard.join(", ")) : null,
      h("div", { class: "list", style: { marginTop: "12px" } },
        query.flow && next ? h("button", { class: "btn primary full", onclick: () => { closeSheet(); go(`#/s/${sid}/sec/${next}?flow=1`); } }, `Next: ${cap(next)}`) : null,
        h("button", { class: (query.flow && next ? "btn" : "btn primary") + " full", onclick: () => { closeSheet(); go(`#/s/${sid}`); } }, "Back to the subject"),
        h("button", { class: "btn full", onclick: () => { closeSheet(); go(`#/s/${sid}/export`); } }, "Export..."),
        h("button", { class: "btn ghost full", onclick: closeSheet }, "Keep editing")));
  }

  const node = h("div", {},
    meta && meta.skeleton ? h("div", { class: "note-box small" }, "Skeleton section: kept so links and \"Edit this\" jumps work.") : null,
    sec === "details" ? h("label", { class: "field" }, h("span", {}, "Name (required)"), nameIn) : null,
    h("div", { class: "seg" }, h("button", { class: raw ? "" : "on", onclick: (e) => { try { data = collect(); } catch (x) { return toast("Fix the JSON first"); } raw = false; e.target.classList.add("on"); e.target.nextSibling.classList.remove("on"); draw(); } }, "Fields"),
      h("button", { class: raw ? "on" : "", onclick: (e) => { try { data = collect(); } catch (x) { return; } raw = true; e.target.classList.add("on"); e.target.previousSibling.classList.remove("on"); draw(); } }, "JSON")),
    formEl,
    h("details", { class: "card" }, h("summary", {}, "Add a field"), newKey, h("div", { style: { height: "8px" } }), newType, h("div", { style: { height: "8px" } }), h("button", { class: "btn full", onclick: addField }, "Add")),
    err,
    h("button", { class: "btn primary full", onclick: () => save(true) }, "Save locally and review"),
    h("p", { class: "small muted" }, "Changes also autosave when you leave a field or this page."));
  if (sec === "details") nameIn.addEventListener("change", autosave);
  return { title: `${doc.name}: ${cap(sec)}`, node, back: `#/s/${sid}` };
}

// ---- prompts ----------------------------------------------------------------------
export async function prompts({ params }) {
  const sid = params[0];
  const [res, defs] = await Promise.all([loadSubject(sid), get("/prompts")]);
  if (!res.ok) return { title: sid, node: errorBox(res.data) };
  const doc = res.data.subject;
  const p = doc.prompts || {};
  const shared = defs.ok ? defs.data : {};
  const detail = h("textarea", {}); detail.value = p.detail || "";
  const negative = h("textarea", { placeholder: "optional" }); negative.value = p.negative || "";
  const stepNames = Object.keys(shared.steps || {});
  const stepIns = stepNames.map((s) => { const t = h("textarea", { placeholder: "Leave empty to use the shared step prompt" }); t.value = (p.steps || {})[s] || ""; return [s, t]; });
  const err = h("div");
  const save = async () => {
    const r = await post(`/subjects/${sid}/prompts`, { detail: detail.value, negative: negative.value, steps: Object.fromEntries(stepIns.map(([s, t]) => [s, t.value])) });
    if (!r.ok) return err.replaceChildren(errorBox(r.data));
    toast("Prompts saved locally");
    if (r.data.flagged && r.data.flagged.length) toast("Linked flagged potentially dirty: " + r.data.flagged.map((f) => f.id).join(", "), 4000);
  };
  const node = h("div", {},
    h("div", { class: "card small" }, h("b", {}, "Shared layers (read only here)"),
      h("p", { class: "muted" }, h("b", {}, "Global: "), shared.global || "-"),
      h("p", { class: "muted" }, h("b", {}, `${cap(doc.type)}: `), (shared.types || {})[doc.type] || "-")),
    h("label", { class: "field" }, h("span", {}, "This subject's details (sent at every step)"), detail),
    h("label", { class: "field" }, h("span", {}, "Things to avoid"), negative),
    h("h3", {}, "Per-step overrides"),
    stepIns.map(([s, t]) => h("label", { class: "field" }, h("span", {}, `${s} - shared: ${(shared.steps || {})[s]}`), t)),
    err, h("button", { class: "btn primary full", onclick: save }, "Save locally"));
  return { title: `${doc.name}: prompts`, node, back: `#/s/${sid}` };
}

// ---- start from reference -------------------------------------------------------------
export async function reference({ params }) {
  const sid = params[0];
  const res = await loadSubject(sid);
  if (!res.ok) return { title: sid, node: errorBox(res.data) };
  const doc = res.data.subject;
  const ref = (doc.studio || {}).reference;
  let mode = "upload";
  const err = h("div");
  const file = h("input", { type: "file", accept: "image/png,image/jpeg,image/webp" });
  const url = h("input", { type: "url", placeholder: "https://..." });
  const body = h("div");
  const seg = h("div", { class: "seg" });
  const modes = [["upload", "Upload"], ["url", "Image link"], ["post", "X post"]];
  function draw() {
    seg.replaceChildren(...modes.map(([m, l]) => h("button", { class: m === mode ? "on" : "", onclick: () => { mode = m; draw(); } }, l)));
    url.placeholder = mode === "post" ? "https://x.com/NAME/status/ID" : "https://.../image.png";
    body.replaceChildren(mode === "upload" ? h("label", { class: "field" }, h("span", {}, "Picture from this phone"), file) : h("label", { class: "field" }, h("span", {}, mode === "post" ? "Post link" : "Image link"), url));
  }
  draw();
  const store = async () => {
    let payload;
    if (mode === "upload") {
      const f = file.files[0];
      if (!f) return toast("Pick a picture");
      const b64 = await new Promise((resolve, reject) => { const r = new FileReader(); r.onload = () => resolve(String(r.result).split(",")[1]); r.onerror = reject; r.readAsDataURL(f); });
      payload = { kind: "upload", filename: f.name, data: b64 };
    } else payload = { kind: mode, value: url.value.trim() };
    const r = await post(`/subjects/${sid}/reference`, payload);
    if (!r.ok) return err.replaceChildren(errorBox(r.data));
    toast("Reference stored on the subject");
    window.dispatchEvent(new HashChangeEvent("hashchange"));
  };
  const ingest = async () => {
    const job = await jobs.start("reference", sid, {});
    if (job) go(`#/job/${job.id}`);
  };
  const ing = ref && ref.ingest;
  const node = h("div", {},
    ref ? h("div", { class: "card" }, h("b", {}, "Current reference"), h("p", { class: "mono" }, ref.url || ref.path), ref.path ? h("img", { class: "big-img", src: fileUrl(ref.path) }) : null,
      h("button", { class: "btn primary full", onclick: ingest }, ing ? "Ingest again" : "Ingest: extract and describe")) : null,
    ing ? h("div", { class: "card" }, h("b", {}, "What the vision pass saw"), ing.simulated ? h("span", { class: "chip sim" }, "simulated") : null,
      h("div", { class: "compare", style: { marginTop: "8px" } }, h("img", { src: fileUrl(ing.image) }), h("div", { class: "small" }, h("p", {}, ing.description),
        h("b", {}, "Mannequin"), h("ul", {}, (ing.mannequin || []).map((m) => h("li", {}, m))), h("b", {}, "Traits"), h("ul", {}, (ing.traits || []).map((m) => h("li", {}, m))))),
      h("a", { class: "btn primary full", href: `#/s/${sid}/sec/${sectionsOf(doc.type).find((s) => ["body", "description", "art", "overview"].includes(s.id))?.id || "details"}?flow=1` }, "Continue into the normal flow")) : null,
    h("h3", {}, ref ? "Replace the reference" : "Add a reference"),
    seg, body, err, h("button", { class: "btn" + (ref ? "" : " primary") + " full", onclick: store }, "Store on the subject"),
    h("p", { class: "small muted" }, "The reference is stored on the subject record. Ingest pulls the image and describes it; the result stays pinned for side-by-side comparison."));
  return { title: `${doc.name}: reference`, node, back: `#/s/${sid}` };
}

// ---- export ------------------------------------------------------------------------
export async function exportView({ params }) {
  const sid = params[0];
  const res = await loadSubject(sid);
  if (!res.ok) return { title: sid, node: errorBox(res.data) };
  const { subject: doc, stills } = res.data;
  const edited = (doc.studio || {}).edited || {};
  const since = doc.exported_at ? Date.parse(doc.exported_at) : 0;
  const secs = sectionsOf(doc.type);
  const changed = (id) => edited[id] && Date.parse(edited[id]) > since;
  const boxes = secs.map((s) => { const c = h("input", { type: "checkbox" }); c.checked = !!changed(s.id); return [s, c]; });
  const bypass = h("input", { type: "checkbox" });
  const pending = stills.filter((s) => s.state === "pending");
  const rejected = stills.filter((s) => s.state === "rejected");
  const gates = res.data.gates || {};
  const heldByApprovals = gates.export && !gates.export.ok;
  const err = h("div");
  const hard = doc.dirty.hard, soft = doc.dirty.soft;
  const run = async () => {
    const areas = boxes.filter(([, c]) => c.checked).map(([s]) => s.id);
    if (!areas.length) return toast("Pick at least one section");
    if (heldByApprovals) return err.replaceChildren(errorBox({ error: "Every current still needs your OK before export. The dirty-flag bypass does not skip that." }));
    if (hard.length && !bypass.checked) return err.replaceChildren(errorBox({ error: "Hard flags hold this export. Resolve them or tick bypass." }));
    const job = await jobs.start("export", sid, { areas, bypass: bypass.checked });
    if (job) go(`#/job/${job.id}`);
  };
  const node = h("div", {},
    h("h3", {}, "1. Select"),
    h("p", { class: "small muted" }, doc.exported_at ? `Ticked: edited since the last export (${when(doc.exported_at)}).` : "Never exported. Ticked: every section edited so far."),
    h("div", { class: "card" }, boxes.map(([s, c]) => h("label", { class: "check" }, c, h("span", { class: "grow" }, cap(s.id)),
      changed(s.id) ? h("span", { class: "badge pending" }, "changed") : null, s.skeleton ? h("span", { class: "badge skeleton" }, "skeleton") : null))),
    h("h3", {}, "2. Review"),
    hard.length ? h("div", { class: "error-box" }, h("b", {}, "Needs regeneration (hard)"), h("div", { class: "row", style: { marginTop: "6px" } }, flagChips({ ...doc, dirty: { hard, soft: [] } }, () => window.dispatchEvent(new HashChangeEvent("hashchange")))),
      h("label", { class: "check" }, bypass, h("span", {}, "Bypass: export anyway"))) : null,
    soft.length ? h("div", { class: "note-box" }, h("b", {}, "Potentially dirty"), h("div", { class: "row", style: { marginTop: "6px" } }, flagChips({ ...doc, dirty: { hard: [], soft } }, () => window.dispatchEvent(new HashChangeEvent("hashchange"))))) : null,
    heldByApprovals ? h("div", { class: "error-box" }, gateNote(gates, "export", sid)) : null,
    !hard.length && !soft.length && !heldByApprovals ? h("span", { class: "chip ok" }, "Nothing holds this export") : null,
    h("h3", {}, "3. Run"),
    err, h("button", { class: "btn primary full", onclick: run, disabled: heldByApprovals, title: heldByApprovals ? "Approve every current still first" : "" }, "Export to the game"),
    h("p", { class: "small muted" }, app.info.simulated ? "Simulated: the export goes to the _sim store, not data/pipeline/export." : "Writes data/pipeline/export/<type>/<id>.json and the export index."));
  return { title: `${doc.name}: export`, node, back: `#/s/${sid}` };
}
