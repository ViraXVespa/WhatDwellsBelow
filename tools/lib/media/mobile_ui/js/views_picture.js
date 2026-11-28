// The big picture screen, the Adjust panel and the action form, all inside one step.
import { fileUrl, get, post } from "./api.js";
import { viewer } from "./glb.js";
import * as jobs from "./jobs.js";
import { app, command, go } from "./state.js";
import { choose, errorBox, h, haptic, showError, toast, when } from "./ui.js";
import { checkCard } from "./views_subject.js";
import {
  actionLabel, details, gateText, guarded, human, loadSubject, notReady, PICTURE_STATE, pictureName, techRows, VIEW_WORD,
} from "./subject_ui.js";

const refresh = () => window.dispatchEvent(new HashChangeEvent("hashchange"));
const picHref = (sid, step, path) => (step ? `#/s/${sid}/step/${step}/pic?path=${encodeURIComponent(path)}` : `#/s/${sid}/pic?path=${encodeURIComponent(path)}`);
const SETTINGS = [
  ["seed", "Variation number", "The same number gives the same picture again."],
  ["strength", "How much it may change", "0 keeps it, 1 redraws it."],
  ["steps", "Detail passes", "More is slower and more detailed."],
  ["width", "Width", "Pixels."],
  ["height", "Height", "Pixels."],
];

// ---- big picture -------------------------------------------------------------------
export async function picture({ params, query }) {
  const [sid, stepId] = params;
  const path = query.path || "";
  const res = await loadSubject(sid);
  if (!res.ok) return { title: "Not found", node: errorBox(res.data), back: "#/" };
  const { subject: doc, stills, steps, reviews } = res.data;
  const pics = stills.filter((s) => (stepId ? s.step === stepId : !s.step));
  const idx = pics.findIndex((s) => s.path === path);
  const pic = pics[idx];
  const back = stepId ? `#/s/${sid}/step/${stepId}` : `#/s/${sid}`;
  if (!pic) return { title: doc.name, node: errorBox({ error: "That picture is not here any more." }), back };
  const s = steps.find((x) => x.id === stepId);
  const open = s ? s.available && s.status !== "done" : true;
  let view = pic.view || "";
  const viewSeg = h("div", { class: "seg" });
  const drawView = () => viewSeg.replaceChildren(...["front", "side", "back", "other"].map((v) => h("button", { class: v === view ? "on" : "", disabled: !open, onclick: () => { view = v; drawView(); } }, VIEW_WORD[v])));
  drawView();
  const setState = async (state) => {
    if (state === "approved" && pic.kind === "still" && !view) return toast("First say which side this picture shows.");
    const body = { path, state };
    if (pic.kind === "still" && view) body.view = view;
    const r = await post(`/subjects/${sid}/stills`, body);
    if (!r.ok) return showError(r);
    haptic(); toast({ approved: "Approved", rejected: "Rejected", hidden: "Hidden" }[state] || "Undone");
    const nextPending = pics.find((x, i) => i !== idx && x.state === "pending");
    if (state !== "pending" && nextPending) go(picHref(sid, stepId, nextPending.path)); else go(back);
  };
  const media = pic.kind === "mesh" ? viewer(fileUrl(pic.path, pic.mtime))
    : pic.kind === "sound" ? h("audio", { controls: true, src: fileUrl(pic.path, pic.mtime), style: { width: "100%" } })
    : h("img", { class: "big-img", src: fileUrl(pic.path, pic.mtime), alt: pic.kind === "clip" ? "animation" : "picture" });
  const nav = (d) => { const x = pics[idx + d]; if (x) go(picHref(sid, stepId, x.path)); };
  const ref = (doc.studio || {}).reference || {};
  const refImg = (ref.ingest && ref.ingest.image) || ref.path;
  const checks = reviews.filter((r) => r.image === pic.path);
  // Pictures not on a step yet: put them on one.
  const homes = steps.filter((x) => x.kind === "pictures" && x.available && x.status !== "done");
  const place = h("select", {}, h("option", { value: "" }, "Pick a step"), homes.map((x) => h("option", { value: x.id }, x.label)));
  const node = h("div", { class: "pic-screen" },
    h("div", { class: "row between" }, h("span", { class: "badge " + pic.state }, PICTURE_STATE[pic.state]), h("span", { class: "small muted" }, `${idx + 1} of ${pics.length}`)),
    pic.clip ? h("p", {}, h("b", {}, "Animation: "), human(pic.clip)) : null,
    h("div", { style: { margin: "8px 0" } }, media),
    !stepId ? h("div", { class: "card" }, h("b", {}, "Put this on a step"), place,
      h("button", { class: "btn primary full", style: { marginTop: "8px" }, onclick: async () => {
        if (!place.value) return toast("Pick a step");
        const r = await post(`/subjects/${sid}/stills`, { path, state: pic.state, step: place.value });
        if (!r.ok) return showError(r);
        toast("Moved"); go(picHref(sid, place.value, path));
      } }, "Move it")) : null,
    stepId && !open ? h("div", { class: "note-box small" }, s.status === "done" ? "This step is approved. Reopen it to change its pictures." : `Finish ${s.blocked_by_label} first.`) : null,
    pic.kind === "still" ? h("div", {}, h("p", { class: "small muted" }, "Which side does it show?"), viewSeg) : null,
    stepId && open ? [
      h("div", { class: "btn-row" },
        h("button", { class: "btn good", onclick: () => setState("approved") }, "Approve"),
        h("button", { class: "btn bad", onclick: () => setState("rejected") }, "Reject"),
        h("button", { class: "btn primary", onclick: () => regenerate(sid, stepId, pic) }, "Regenerate")),
      pic.state === "rejected" ? h("button", { class: "btn full", onclick: () => setState("hidden") }, "Hide it") : null,
      pic.state !== "pending" ? h("button", { class: "btn ghost full", onclick: () => setState("pending") }, pic.state === "hidden" ? "Show it again" : "Undo") : null] : null,
    h("div", { class: "btn-row" }, h("button", { class: "btn", onclick: () => nav(-1), disabled: idx <= 0 }, "Newer"), h("button", { class: "btn", onclick: () => nav(1), disabled: idx >= pics.length - 1 }, "Older")),
    checks.length ? h("div", { class: "card" }, h("b", {}, "Check results"), checks.map(checkCard)) : null,
    refImg && pic.kind === "still" ? h("details", { class: "card" }, h("summary", {}, "Compare with the reference"), h("div", { class: "compare" }, h("img", { src: fileUrl(pic.path, pic.mtime) }), h("img", { src: fileUrl(refImg) }))) : null,
    details("Details", techRows([["file", pic.path], pic.cmd ? ["made by", `${pic.cmd} (job ${pic.job})`] : null, pic.args ? ["settings", pic.args] : null,
      ["size", `${Math.round(pic.size / 1024)} KB`], ["made", when(pic.mtime)], pic.simulated ? ["practice", "yes"] : null])));
  return { title: s ? `${doc.name}: ${s.label}` : doc.name, node, back, tab: "home" };
}

async function regenerate(sid, stepId, pic) {
  const how = await choose("Regenerate", "Make a new version with the same settings, or adjust them first.", [
    { label: "Same settings", value: "same", cls: "primary" }, { label: "Adjust first", value: "adjust" }]);
  if (!how) return;
  const step = (await loadSubject(sid)).data.steps.find((x) => x.id === stepId) || { actions: [] };
  const cmd = pic.cmd && command(pic.cmd) ? pic.cmd : pic.kind === "mesh" ? "body" : ["generate", "variant", "tile", "tune"].find((c) => step.actions.includes(c)) || "tune";
  if (how === "adjust") return go(`#/s/${sid}/step/${stepId}/adjust?then=${cmd}&from=${encodeURIComponent(pic.path)}`);
  if (pic.cmd && pic.args) {
    const job = await jobs.start(cmd, sid, pic.args, { step: stepId });
    if (job) go(`#/job/${job.id}`);
  } else go(`#/s/${sid}/step/${stepId}/do/${cmd}?from=${encodeURIComponent(pic.path)}`);
}

// ---- adjust ------------------------------------------------------------------------
export async function adjust({ params, query }) {
  const [sid, stepId] = params;
  const [res, shared] = await Promise.all([loadSubject(sid), get("/prompts")]);
  if (!res.ok) return { title: "Not found", node: errorBox(res.data), back: "#/" };
  const { subject: doc, steps, overrides } = res.data;
  const s = steps.find((x) => x.id === stepId);
  const back = `#/s/${sid}/step/${stepId}`;
  if (!s || s.kind !== "pictures") return { title: doc.name, node: errorBox({ error: "This step has no pictures to adjust." }), back };
  const p = shared.ok ? shared.data : {};
  const std = {
    prompt: [p.global, (p.types || {})[doc.type], (doc.prompts || {}).detail].filter(Boolean).join(" "),
    negative: (doc.prompts || {}).negative || "",
  };
  const mine = overrides[stepId] || {};
  const open = s.available && s.status !== "done";
  const prompt = h("textarea", { rows: 4, disabled: !open }); prompt.value = mine.prompt ?? std.prompt;
  const negative = h("textarea", { rows: 2, disabled: !open, placeholder: "Nothing" }); negative.value = mine.negative ?? std.negative;
  const ins = Object.fromEntries(SETTINGS.map(([k]) => {
    const el = h("input", { type: "number", step: "any", placeholder: "Automatic", disabled: !open });
    if ((mine.settings || {})[k] !== undefined) el.value = mine.settings[k];
    return [k, el];
  }));
  const changes = h("div");
  const collect = () => {
    const out = { step: stepId, settings: {} };
    if (prompt.value.trim() !== std.prompt.trim()) out.prompt = prompt.value.trim();
    if (negative.value.trim() !== std.negative.trim()) out.negative = negative.value.trim();
    for (const [k, el] of Object.entries(ins)) if (el.value !== "") out.settings[k] = Number(el.value);
    return out;
  };
  const drawChanges = () => {
    const c = collect();
    const rows = [];
    if (c.prompt !== undefined) rows.push(["Description", "changed"]);
    if (c.negative !== undefined) rows.push(["What to avoid", c.negative || "cleared"]);
    for (const [k, label] of SETTINGS) if (c.settings[k] !== undefined) rows.push([label, String(c.settings[k])]);
    changes.replaceChildren(rows.length ? h("ul", { class: "small" }, rows.map(([a, b]) => h("li", {}, h("b", {}, a + ": "), b))) : h("p", { class: "small muted" }, "Nothing changed. The standard settings are used."));
  };
  for (const el of [prompt, negative, ...Object.values(ins)]) el.addEventListener("input", drawChanges);
  drawChanges();
  const err = h("div");
  const save = async () => {
    const r = await post(`/subjects/${sid}/overrides`, collect());
    if (!r.ok) { err.replaceChildren(errorBox(r.data)); return false; }
    toast("Saved for this step");
    return true;
  };
  const then = query.then && s.actions.includes(query.then) && !guarded(sid).includes(query.then) ? query.then : null;
  const node = h("div", {},
    h("p", { class: "small muted" }, `These settings apply to new pictures on ${s.label} for ${doc.name} only.`),
    h("label", { class: "field" }, h("span", {}, "Describe what to make"), prompt),
    h("label", { class: "field" }, h("span", {}, "What to avoid"), negative),
    h("details", { class: "card" }, h("summary", {}, "More settings"),
      SETTINGS.map(([k, label, hint]) => h("label", { class: "field" }, h("span", {}, label), ins[k], h("small", { class: "muted" }, hint)))),
    h("div", { class: "card" }, h("b", {}, "What changed"), changes),
    err,
    open ? [
      h("button", { class: "btn primary full", onclick: async () => {
        if (!(await save())) return;
        if (then) go(`#/s/${sid}/step/${stepId}/do/${then}${query.from ? "?from=" + encodeURIComponent(query.from) : ""}`); else go(back);
      } }, then ? "Save and continue" : "Save"),
      h("button", { class: "btn ghost full", onclick: async () => {
        const ok = await choose("Reset to standard?", "Your changes for this step are removed.", [{ label: "Reset", value: true, cls: "primary" }]);
        if (!ok) return;
        const r = await post(`/subjects/${sid}/overrides`, { step: stepId, reset: true });
        if (!r.ok) return showError(r);
        toast("Back to standard"); refresh();
      } }, "Reset to standard")] : h("div", { class: "note-box small" }, "This step is not open right now."),
    details("Details", techRows([["standard description", std.prompt], ["saved", mine.at || "-"], ["saved values", mine]])));
  return { title: `${doc.name}: adjust ${s.label}`, node, back, tab: "home" };
}

// ---- action form -------------------------------------------------------------------
export async function action({ params, query }) {
  const [sid, stepId, cmd] = params;
  const res = await loadSubject(sid);
  if (!res.ok) return { title: "Not found", node: errorBox(res.data), back: "#/" };
  const data = res.data;
  const { subject: doc, steps } = data;
  const s = steps.find((x) => x.id === stepId);
  const back = `#/s/${sid}/step/${stepId}`;
  const spec = command(cmd);
  if (!s || !spec || !s.actions.includes(cmd) || guarded(sid).includes(cmd)) return { title: doc.name, node: errorBox({ error: "That is not something this step does." }), back };
  if (!s.available || s.status === "done") return { title: doc.name, node: errorBox({ error: s.status === "done" ? "This step is approved. Reopen it first." : `Finish ${s.blocked_by_label} first.` }), back };
  const onStep = data.stills.filter((x) => x.step === stepId);
  const pool = (kind) => {
    const want = kind === "glb" ? "mesh" : "still";
    const here = onStep.filter((x) => x.kind === want);
    return here.length ? here : data.stills.filter((x) => x.kind === want && x.state !== "rejected");
  };
  if (notReady(s, cmd)) {
    return { title: actionLabel(cmd), back, tab: "home", node: h("div", {},
      h("div", { class: "card locked-card" }, h("b", {}, "Not set up yet"),
        h("p", { class: "muted" }, `${actionLabel(cmd)} on ${s.label} is not set up yet. It works in practice mode. See Coverage, Left to build.`),
        h("a", { class: "btn full", href: "#/coverage?show=build" }, "See what is left to build"))) };
  }
  const from = data.stills.find((x) => x.path === query.from);
  const stepData = ((doc.sections || {})[stepId] || {}).data || {};
  const clips = stepData.clips || [];
  // Make Wang tileset starts from the first row of the step's Wang tilesets table.
  const prefill = (cmd === "wang" && (stepData.wang || [])[0]) || {};
  const start = (f) => prefill[f.name] ?? f.default ?? "";
  const visible = [], advanced = [], read = {};
  for (const f of spec.fields) {
    if (f.kind === "still" || f.kind === "glb") {
      const opts = pool(f.kind);
      let chosen = from && (from.kind === "mesh") === (f.kind === "glb") && f.required ? from.path : "";
      const grid = h("div", { class: "thumbs pick" });
      const draw = () => grid.replaceChildren(...(opts.length ? opts.map((x) => h("button", { class: "thumb " + (x.path === chosen ? "chosen" : ""), onclick: () => { chosen = chosen === x.path ? "" : x.path; draw(); } },
        x.kind === "mesh" ? h("div", { class: "glbmark" }, "3D") : h("img", { src: fileUrl(x.path, x.mtime), alt: "picture" }),
        x.view ? h("span", { class: "view-tag" }, VIEW_WORD[x.view]) : null)) : [h("p", { class: "muted small" }, "Nothing to pick yet.")]));
      draw();
      read[f.name] = () => chosen;
      const label = f.kind === "glb" ? "Which 3D model" : f.required ? "Which picture" : `${human(f.name)} picture (optional)`;
      (f.required || cmd !== "body" ? visible : advanced).push(h("div", { class: "field" }, h("span", {}, label), grid));
    } else if (f.kind === "role") {
      const sel = h("select", {}, h("option", { value: "" }, f.required ? "Pick one" : "Automatic"), (app.info.roles || []).map((r) => h("option", { value: r }, human(r))));
      if (from && from.view && ["front", "side", "back"].includes(from.view)) {
        const guess = (app.info.roles || []).find((r) => r === `mannequin-${from.view}`);
        if (guess) sel.value = guess;
      }
      read[f.name] = () => sel.value;
      visible.push(h("label", { class: "field" }, h("span", {}, "What to check it against"), sel));
    } else if (f.kind === "int") {
      const el = h("input", { type: "number", value: f.default ?? "" });
      read[f.name] = () => (el.value ? Number(el.value) : null);
      visible.push(h("label", { class: "field" }, h("span", {}, f.name === "turns" ? "How many tries" : f.label), el));
    } else if (f.kind === "text") {
      const change = ["edit", "variant"].includes(cmd);
      const el = h(change ? "textarea" : "input", { type: "text", placeholder: change ? "Say what should change" : "", value: start(f) });
      read[f.name] = () => el.value.trim();
      visible.push(h("label", { class: "field" }, h("span", {}, change ? "What should change?" : f.label + (f.required ? "" : " (optional)")), el));
    } else if (f.kind === "choice" || f.kind === "clip") {
      const opts = f.kind === "clip" ? clips : f.options || [];
      const sel = h("select", {}, h("option", { value: "" }, "Pick one"), opts.map((o) => h("option", { value: o }, (f.labels || {})[o] || human(o))));
      if (f.kind === "choice" && opts.includes(String(start(f)))) sel.value = String(start(f));
      const firstMissing = f.kind === "clip" ? opts.find((c) => !data.stills.some((x) => x.step === stepId && x.clip === c && x.state === "approved")) : null;
      if (firstMissing) sel.value = firstMissing;
      read[f.name] = () => sel.value;
      visible.push(h("label", { class: "field" }, h("span", {}, f.kind === "clip" ? "Which animation" : f.label), opts.length ? sel : h("p", { class: "muted small" }, "List the clips on this step first.")));
    } else if (f.name === "workflow" && cmd !== "correct") {
      // The step's default recipe fills this in; nothing to ask.
    } else if (f.kind === "path" || f.kind === "str") {
      const dflt = f.name === "out" && cmd === "frame" ? `data/pipeline/wip/gen/${sid}-framed-${Date.now().toString(36)}.png` : f.default || "";
      const el = h("input", { type: "text", value: dflt });
      read[f.name] = () => el.value.trim();
      advanced.push(h("label", { class: "field" }, h("span", {}, f.label + (f.required ? " (needed)" : "")), el));
    }
  }
  const needsAdvanced = spec.fields.some((f) => (f.kind === "path" || f.kind === "str") && f.required && !(f.name === "out" && cmd === "frame") && !(f.name === "workflow" && cmd !== "correct"));
  const gate = (cmd === "body" || cmd === "mesh") ? data.gates[cmd] : null;
  const blocked = gate && !gate.ok;
  const adjusted = Object.keys((data.overrides || {})[stepId] || {}).length > 1;
  const err = h("div");
  const run = h("button", { class: "btn primary full", disabled: blocked }, actionLabel(cmd));
  run.onclick = async () => {
    const args = {};
    for (const [k, r] of Object.entries(read)) { const v = r(); if (v !== "" && v !== null && v !== false) args[k] = v; }
    const missing = spec.fields.filter((f) => f.required && !args[f.name] && !(f.name === "workflow" && cmd !== "correct"));
    if (missing.length) return err.replaceChildren(errorBox({ error: missing.some((f) => ["still", "glb", "choice", "clip"].includes(f.kind)) ? "Pick one first." : missing.some((f) => f.kind === "role") ? "Pick what to check it against."
      : missing.some((f) => f.kind === "text") ? `Fill in ${missing.filter((f) => f.kind === "text").map((f) => f.label.toLowerCase()).join(" and ")}.` : "Something is missing. Open Details." }));
    run.disabled = true;
    const job = await jobs.start(cmd, sid, args, { step: stepId });
    run.disabled = false;
    if (job) go(`#/job/${job.id}`);
  };
  const node = h("div", {},
    visible, blocked ? h("div", { class: "note-box small" }, gateText(gate)) : null,
    adjusted ? h("p", { class: "small" }, "Uses your adjusted settings for this step. ", h("a", { href: `#/s/${sid}/step/${stepId}/adjust` }, "Change them")) : null,
    advanced.length ? h("details", { class: "card details", open: needsAdvanced }, h("summary", {}, "Details"), advanced) : null,
    err, run,
    app.info.simulated ? h("p", { class: "small muted" }, "Practice mode: shows made-up results.") : null);
  return { title: actionLabel(cmd), node, back, tab: "home" };
}
