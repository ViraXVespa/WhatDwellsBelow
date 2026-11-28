// Preview (approval queue, stills, compare, GLB), still view with approve / reject / regenerate,
// review results, generation forms, jobs.
import { fileUrl, get, post } from "./api.js";
import { viewer } from "./glb.js";
import * as jobs from "./jobs.js";
import * as notify from "./notify.js";
import { app, command, go, loadSubjects } from "./state.js";
import { basename, cap, choose, errorBox, h, haptic, showError, toast, when } from "./ui.js";
import { gateNote, jobRow, loadSubject, thumb } from "./views_subject.js";

const refresh = () => window.dispatchEvent(new HashChangeEvent("hashchange"));

export async function previewQueue() {
  await loadSubjects();
  const withPending = app.subjects.filter((s) => s.pending);
  const shown = await Promise.all(withPending.map((s) => loadSubject(s.id)));
  const groups = shown.filter((r) => r.ok).map((r) => ({ doc: r.data.subject, stills: r.data.stills.filter((s) => s.state === "pending") }));
  const node = h("div", {},
    h("p", { class: "muted" }, "Everything waiting on your call. Tap a still to approve, reject or regenerate it."),
    groups.length ? groups.map((g) => h("div", { class: "card" },
      h("div", { class: "row between" }, h("b", {}, g.doc.name), h("a", { href: `#/preview/${g.doc.id}` }, "All stills")),
      h("div", { class: "thumbs", style: { marginTop: "8px" } }, g.stills.map((s) => thumb(s, g.doc.id))))) : h("div", { class: "card" }, h("b", {}, "Nothing waits for approval.")),
    h("h3", {}, "Subjects"),
    h("div", { class: "list" }, app.subjects.map((s) => h("a", { class: "item", href: `#/preview/${s.id}` }, h("div", { class: "grow" }, h("b", {}, s.name), h("small", {}, s.type)),
      s.pending ? h("span", { class: "badge pending" }, `${s.pending} pending`) : null))));
  return { title: "Preview", node, tab: "preview" };
}

export async function previewSubject({ params }) {
  const sid = params[0];
  const res = await loadSubject(sid);
  if (!res.ok) return { title: sid, node: errorBox(res.data), tab: "preview" };
  const { subject: doc, stills } = res.data;
  let filter = "all", picks = [];
  const grid = h("div", { class: "thumbs" });
  const cmp = h("div");
  const seg = h("div", { class: "seg" });
  const ref = ((doc.studio || {}).reference || {});
  const refImg = (ref.ingest && ref.ingest.image) || ref.path;
  function draw() {
    seg.replaceChildren(...["all", "pending", "approved", "rejected", "compare"].map((f) => h("button", { class: f === filter ? "on" : "", onclick: () => { filter = f; picks = []; draw(); } }, cap(f))));
    const rows = stills.filter((s) => filter === "all" || filter === "compare" || s.state === filter).filter((s) => filter !== "compare" || s.kind === "still");
    grid.replaceChildren(...rows.map((s) => thumb(s, sid, filter === "compare" ? () => { picks = [...picks.filter((p) => p !== s), s].slice(-2); drawCompare(); } : null)));
    drawCompare();
  }
  function drawCompare() {
    if (filter !== "compare") return cmp.replaceChildren();
    const [a, b] = picks;
    const img = (s, label) => h("div", {}, s ? h("img", { src: fileUrl(s.path, s.mtime) }) : h("div", { class: "thumb" }), h("div", { class: "small muted mono" }, s ? `${label}: ${basename(s.path)}` : `Tap a still for ${label.toLowerCase()}`));
    cmp.replaceChildren(h("div", { class: "card" }, h("b", {}, "Before / after"), h("div", { class: "compare", style: { marginTop: "8px" } }, img(a, "Before"), img(b, "After")),
      refImg ? h("p", { class: "small muted" }, "Reference pinned below.") : null, refImg ? h("img", { class: "big-img", style: { maxHeight: "30vh", marginTop: "6px" }, src: fileUrl(refImg) }) : null));
  }
  draw();
  const node = h("div", {}, h("div", { class: "row between" }, h("b", {}, doc.name), h("a", { href: `#/s/${sid}` }, "Subject")), seg, cmp, stills.length ? grid : h("p", { class: "muted" }, "Nothing generated yet."),
    h("div", { class: "card small muted", style: { marginTop: "12px" } }, "In-game capture (pack to a worktree, run, record) is not wired yet; stills and meshes preview here."));
  return { title: `Preview: ${doc.name}`, node, tab: "preview", back: `#/s/${sid}` };
}

async function regenerate(sid, still) {
  if (still.cmd && command(still.cmd)) {
    const go2 = await choose("Regenerate", `Run ${still.cmd} again with the same settings, or change them first.`, [
      { label: `Run ${still.cmd} again`, value: "same", cls: "primary" }, { label: "Change settings first", value: "edit" }]);
    if (go2 === "same") { const job = await jobs.start(still.cmd, sid, still.args || {}); if (job) go(`#/job/${job.id}`); }
    if (go2 === "edit") go(`#/s/${sid}/gen/${still.cmd}?${new URLSearchParams(Object.entries(still.args || {}).map(([k, v]) => [k, String(v)]))}`);
    return;
  }
  const kind = still.kind === "mesh" ? "glb" : "image";
  const pick = await choose("Regenerate from this", "This file was not made by a studio job. Pick the command to run with it.", (still.kind === "mesh" ? ["mesh", "proportion", "edit"] : ["tune", "review", "frame", "proportion"])
    .map((c) => ({ label: command(c).label, value: c, cls: c === "tune" ? "primary" : "" })));
  if (pick) go(`#/s/${sid}/gen/${pick}?${kind}=${encodeURIComponent(still.path)}`);
}

export async function stillView({ params, query }) {
  const sid = params[0];
  const path = query.path || "";
  const res = await loadSubject(sid);
  if (!res.ok) return { title: sid, node: errorBox(res.data) };
  const { subject: doc, stills } = res.data;
  const idx = stills.findIndex((s) => s.path === path);
  const still = stills[idx];
  if (!still) return { title: basename(path), node: errorBox({ error: "This file is not on the subject (or is not presented)." }), back: `#/preview/${sid}` };
  let view = still.view || "";
  const viewSeg = h("div", { class: "seg" });
  const drawView = () => viewSeg.replaceChildren(...["front", "side", "back", "other"].map((v) => h("button", { class: v === view ? "on" : "", onclick: () => { view = v; drawView(); } }, cap(v))));
  drawView();
  const setState = async (state) => {
    if (state === "approved" && still.kind === "still" && !view) {
      toast("Pick a view first: front, side, back, or other.");
      return;
    }
    const body = { path, state };
    if (state === "approved" && still.kind === "still" && view && view !== "other") body.view = view;
    if (state === "approved" && still.kind === "still" && view === "other") body.view = "other";
    const r = await post(`/subjects/${sid}/stills`, body);
    if (!r.ok) return showError(r);
    haptic(); toast(state === "approved" ? "Approved" : state === "rejected" ? "Rejected" : "Back to pending");
    const nextPending = stills.find((s, i) => i !== idx && s.state === "pending");
    if (state !== "pending" && nextPending) go(`#/still/${sid}?path=${encodeURIComponent(nextPending.path)}`); else refresh();
  };
  const ref = ((doc.studio || {}).reference || {});
  const refImg = (ref.ingest && ref.ingest.image) || ref.path;
  const media = still.kind === "mesh" ? viewer(fileUrl(still.path, still.mtime)) : h("img", { class: "big-img", src: fileUrl(still.path, still.mtime), alt: basename(still.path) });
  const nav = (d) => { const s = stills[idx + d]; if (s) go(`#/still/${sid}?path=${encodeURIComponent(s.path)}`); };
  const quick = still.kind === "mesh" ? ["mesh", "proportion"] : ["review", "frame", "proportion"];
  const node = h("div", {},
    h("div", { class: "row between" }, h("span", { class: "badge " + still.state }, still.state), still.view ? h("span", { class: "chip" }, still.view) : null, still.simulated ? h("span", { class: "chip sim" }, "SIMULATED") : null,
      h("span", { class: "small muted" }, `${idx + 1} / ${stills.length}`)),
    h("div", { style: { margin: "8px 0" } }, media),
    still.kind === "still" ? h("div", {}, h("p", { class: "small muted" }, still.view_set || still.view ? "View (change it if the name got it wrong):" : "This file name does not say which view it is. Tag it when you approve."), viewSeg) : null,
    h("div", { class: "btn-row" },
      h("button", { class: "btn good", onclick: () => setState("approved") }, "Approve"),
      h("button", { class: "btn bad", onclick: () => setState("rejected") }, "Reject"),
      h("button", { class: "btn primary", onclick: () => regenerate(sid, still) }, "Regenerate")),
    still.state !== "pending" ? h("button", { class: "btn ghost full", onclick: () => setState("pending") }, "Undo the decision") : null,
    h("div", { class: "btn-row" }, h("button", { class: "btn", onclick: () => nav(-1), disabled: idx <= 0 }, "Newer"), h("button", { class: "btn", onclick: () => nav(1), disabled: idx >= stills.length - 1 }, "Older")),
    refImg && still.kind === "still" ? h("details", { class: "card" }, h("summary", {}, "Compare with the reference"), h("div", { class: "compare" }, h("img", { src: fileUrl(still.path, still.mtime) }), h("img", { src: fileUrl(refImg) }))) : null,
    h("h3", {}, "Use it"),
    h("div", { class: "btn-row" }, quick.map((c) => h("a", { class: "btn", href: `#/s/${sid}/gen/${c}?${still.kind === "mesh" ? "glb" : "image"}=${encodeURIComponent(path)}` }, command(c).label))),
    h("dl", { class: "kv small" }, h("dt", {}, "file"), h("dd", { class: "mono" }, path), still.cmd ? [h("dt", {}, "made by"), h("dd", {}, `${still.cmd} - job ${still.job}`)] : null,
      h("dt", {}, "size"), h("dd", {}, `${Math.round(still.size / 1024)} KB - ${when(still.mtime)}`)));
  return { title: basename(path), node, back: `#/preview/${sid}`, tab: "preview" };
}

export async function reviewView({ params }) {
  const sid = params[0];
  const res = await loadSubject(sid);
  if (!res.ok) return { title: sid, node: errorBox(res.data) };
  const { subject: doc, reviews } = res.data;
  let failsOnly = false;
  const box = h("div");
  const measures = jobs.all().filter((j) => j.subject === sid && ["proportion", "mesh"].includes(j.cmd) && j.result);
  function draw() {
    box.replaceChildren(...reviews.map((r) => h("div", { class: "card" },
      h("div", { class: "row between" }, h("b", {}, r.role), h("span", { class: "badge " + r.verdict }, r.verdict), r.simulated ? h("span", { class: "chip sim" }, "sim") : null),
      h("div", { class: "small muted mono" }, `${basename(r.path)} - ${when(r.mtime)}`),
      r.image ? h("a", { href: `#/still/${sid}?path=${encodeURIComponent(r.image)}` }, "Open the still") : null,
      h("table", { class: "checks" }, r.checks.filter((c) => !failsOnly || !c.pass).map((c) => h("tr", {},
        h("td", {}, h("span", { class: "badge " + (c.pass ? "pass" : "fail") }, c.pass ? "pass" : "fail")), h("td", { class: "mono" }, c.id), h("td", { class: "small" }, c.reason || "")))))));
  }
  draw();
  const node = h("div", {},
    h("label", { class: "check" }, h("input", { type: "checkbox", onchange: (e) => { failsOnly = e.target.checked; draw(); } }), h("span", {}, "Fails only")),
    reviews.length ? box : h("p", { class: "muted" }, "No review JSON for this subject yet. Run Review or Auto-tune."),
    measures.length ? [h("h3", {}, "Proportion and mesh"), measures.map((j) => h("div", { class: "card small" }, h("div", { class: "row between" }, h("b", {}, j.cmd), h("span", { class: "badge " + (j.result.ok ? "pass" : "fail") }, j.result.ok ? "pass" : "fail")),
      h("div", { class: "mono" }, Object.entries(j.result).filter(([k]) => !["added", "ok", "simulated"].includes(k)).map(([k, v]) => `${k}=${typeof v === "object" ? JSON.stringify(v) : v}`).join("  "))))] : null,
    h("p", { class: "small muted" }, "A vision pass does not override proportion."));
  return { title: `${doc.name}: review`, node, back: `#/s/${sid}` };
}

export async function genForm({ params, query }) {
  const [sid, cmd] = params;
  const spec = command(cmd);
  if (!spec) return { title: cmd, node: errorBox({ error: `Unknown command ${cmd}` }) };
  const res = await loadSubject(sid);
  if (!res.ok) return { title: sid, node: errorBox(res.data) };
  const { subject: doc, stills, reviews } = res.data;
  const inputs = {};
  const pathPick = (kind, f) => {
    const opts = kind === "glb" ? stills.filter((s) => s.kind === "mesh") : kind === "review" ? reviews.map((r) => ({ path: r.path, state: r.verdict })) : stills.filter((s) => s.kind === "still");
    const sel = h("select", {}, h("option", { value: "" }, f.required ? "Pick one" : "None"), opts.map((s) => h("option", { value: s.path }, `${basename(s.path)} (${s.state})`)));
    const txt = h("input", { type: "text", placeholder: "or a repo-relative path" });
    const want = query[f.name];
    if (want && opts.some((s) => s.path === want)) sel.value = want; else if (want) txt.value = want;
    return { el: h("div", {}, sel, h("div", { style: { height: "6px" } }), txt), read: () => txt.value.trim() || sel.value };
  };
  const fieldEls = spec.fields.map((f) => {
    let el, read;
    if (["still", "glb", "review"].includes(f.kind)) ({ el, read } = pathPick(f.kind, f));
    else if (f.kind === "role") {
      el = h("select", {}, h("option", { value: "" }, f.required ? "Pick a role" : "None"), (app.info.roles || []).map((r) => h("option", { value: r }, r)));
      el.value = query[f.name] || ""; read = () => el.value;
    } else if (f.kind === "int") { el = h("input", { type: "number", value: query[f.name] || f.default || "" }); read = () => (el.value ? Number(el.value) : null); }
    else if (f.kind === "bool") { el = h("input", { type: "checkbox" }); read = () => el.checked; return { f, read, el: h("label", { class: "check" }, el, h("span", {}, f.label)) }; }
    else if (f.kind === "text") { el = h("textarea", { placeholder: "Describe the change" }); el.value = query[f.name] || ""; read = () => el.value.trim(); }
    else {
      const dflt = f.name === "out" && cmd === "frame" ? `data/pipeline/wip/gen/${sid}-framed.png` : f.default || "";
      el = h("input", { type: "text", value: query[f.name] || dflt }); read = () => el.value.trim();
    }
    inputs[f.name] = read;
    return { f, read, el: h("label", { class: "field" }, h("span", {}, f.label + (f.required ? " *" : "")), el) };
  });
  for (const fe of fieldEls) inputs[fe.f.name] = fe.read;
  const gates = res.data.gates || {};
  const blocked = (cmd === "body" || cmd === "mesh") && gates[cmd] && !gates[cmd].ok;
  const err = h("div");
  const run = h("button", { class: "btn primary full", disabled: blocked }, `Run ${spec.label}`);
  run.onclick = async () => {
    if (blocked) return;
    const args = {};
    for (const [k, read] of Object.entries(inputs)) { const v = read(); if (v !== "" && v !== null && v !== false) args[k] = v; }
    const missing = spec.fields.filter((f) => f.required && !args[f.name]);
    if (missing.length) return err.replaceChildren(errorBox({ error: "Required: " + missing.map((f) => f.label).join(", ") }));
    run.disabled = true;
    const job = await jobs.start(cmd, sid, args);
    run.disabled = false;
    if (job) go(`#/job/${job.id}`);
  };
  const node = h("div", {},
    h("div", { class: "card small" }, h("b", {}, `pipeline ${cmd}`), h("p", { class: "muted" }, spec.about), spec.gpu ? h("span", { class: "badge" }, "model job: one at a time") : h("span", { class: "badge" }, "cpu job")),
    fieldEls.map((x) => x.el), blocked ? gateNote(gates, cmd, sid) : null, err, run,
    app.info.simulated ? h("p", { class: "small muted" }, "Simulated: returns canned results after staged delays.") : null);
  return { title: `${doc.name}: ${spec.label}`, node, back: `#/s/${sid}` };
}

export async function jobsView() {
  await jobs.refresh();
  const s = notify.support();
  const status = h("p", { class: "small muted" }, s.usable ? `Alerts: ${s.permission}` : "Alerts: not available on this http page; a finished job flashes the tab title.");
  const list = h("div", { class: "list" });
  const draw = () => {
    const rows = jobs.all();
    list.replaceChildren(...(rows.length ? rows.map(jobRow) : [h("p", { class: "muted" }, "No jobs yet.")]));
  };
  draw();
  app.cleanup = jobs.subscribe(() => draw());
  const node = h("div", {},
    h("div", { class: "card" }, h("b", {}, "Finished-job alerts"), status,
      h("button", { class: "btn full", onclick: async () => { status.textContent = await notify.enable(); } }, "Turn on alerts")),
    list);
  return { title: "Jobs", node, tab: "jobs" };
}

function resultView(job) {
  const r = job.result || {};
  const sid = job.subject;
  const rows = Object.entries(r).filter(([k]) => !["added", "checks", "simulated"].includes(k));
  return h("div", { class: "card" },
    h("div", { class: "row between" }, h("b", {}, "Result"), r.simulated ? h("span", { class: "chip sim" }, "SIMULATED") : null),
    h("dl", { class: "kv small" }, rows.map(([k, v]) => [h("dt", {}, k), h("dd", { class: "mono" }, typeof v === "object" ? JSON.stringify(v) : String(v))])),
    r.added && r.added.length && sid ? [h("h3", {}, "New files - approve or reject each"), h("div", { class: "thumbs" }, r.added.map((a) => thumb({ ...a, kind: /\.glb$/i.test(a.path) ? "mesh" : "still", state: "pending", mtime: 0 }, sid)))] : null,
    r.review && sid ? h("a", { class: "btn full", href: `#/s/${sid}/review` }, "Open the review") : null,
    r.glb && sid ? h("a", { class: "btn full", href: `#/still/${sid}?path=${encodeURIComponent(r.glb)}` }, "View the mesh") : null);
}

export async function jobView({ params }) {
  const id = params[0];
  let job = jobs.byId(id) && jobs.byId(id).events && jobs.byId(id).events.length ? jobs.byId(id) : await jobs.load(id);
  if (!job) return { title: "Job", node: errorBox({ error: "No such job on the server." }), tab: "jobs", back: "#/jobs" };
  const head = h("div");
  const bar = h("div");
  const log = h("pre", { class: "log" });
  const result = h("div");
  const actions = h("div");
  function draw(j) {
    job = j;
    head.replaceChildren(h("div", { class: "row between" }, h("div", {}, h("b", {}, `pipeline ${j.cmd}`), h("div", { class: "small muted" }, `${j.subject || "-"} - ${when(j.created)}`)),
      j.simulated ? h("span", { class: "chip sim" }, "SIMULATED") : null, h("span", { class: "badge " + j.status }, j.status)));
    bar.replaceChildren(h("p", {}, j.stage || "Waiting"), h("div", { class: "bar" }, h("div", { style: { width: `${j.pct}%` } })));
    log.textContent = (j.events || []).filter((e) => e.kind === "log" || e.kind === "stage").map((e) => (e.kind === "stage" ? "== " : "") + e.msg).join("\n");
    log.scrollTop = log.scrollHeight;
    result.replaceChildren(...[j.error ? errorBox({ error: j.error }) : null, !jobs.isActive(j) && j.result ? resultView(j) : null].filter(Boolean));
    actions.replaceChildren(...[
      jobs.isActive(j) ? h("button", { class: "btn bad full", onclick: () => jobs.cancel(j.id) }, "Cancel") : null,
      j.subject ? h("a", { class: "btn full", href: `#/s/${j.subject}`, style: { marginTop: "8px" } }, "Open the subject") : null,
      !jobs.isActive(j) && j.subject && command(j.cmd) && j.cmd !== "export" ? h("button", { class: "btn full", style: { marginTop: "8px" }, onclick: async () => { const n = await jobs.start(j.cmd, j.subject, j.args || {}); if (n) go(`#/job/${n.id}`); } }, "Run again") : null].filter(Boolean));
  }
  draw(job);
  app.cleanup = jobs.subscribe((j) => { if (j && j.id === id) draw(jobs.byId(id)); });
  if (jobs.isActive(job)) jobs.load(id);
  const node = h("div", {}, h("div", { class: "card" }, head, bar), result, h("details", { class: "card", open: jobs.isActive(job) || job.status === "error" }, h("summary", {}, "Details"), log), actions,
    h("p", { class: "small muted" }, "Jobs run on the PC. You can leave or reload this page; it reconnects."));
  return { title: `Job ${cap(job.cmd)}`, node, tab: "jobs", back: "#/jobs" };
}
