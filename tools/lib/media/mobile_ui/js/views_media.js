// Jobs list and one job. Opened from the working pill, a step, or a finished-job alert.
import * as jobs from "./jobs.js";
import * as notify from "./notify.js";
import { app, command, go, loadSubjects } from "./state.js";
import { errorBox, h, when } from "./ui.js";
import { actionLabel, details, subjectName, techRows, thumb } from "./subject_ui.js";
import { jobWord } from "./views_subject.js";

function jobRow(j) {
  return h("a", { class: "item", href: `#/job/${j.id}` },
    h("div", { class: "grow" }, h("b", {}, actionLabel(j.cmd)), h("small", {}, `${j.subject ? subjectName(j.subject) + " - " : ""}${when(j.created)}`)),
    jobs.isActive(j) ? h("span", { class: "small" }, `${Math.round(j.pct)}%`) : null,
    h("span", { class: "badge " + j.status }, jobWord(j.status)));
}

export async function jobsView() {
  if (!app.subjects) await loadSubjects();
  await jobs.refresh();
  const s = notify.support();
  const status = h("p", { class: "small muted" }, s.usable ? (s.permission === "granted" ? "Alerts are on." : "Alerts are off.") : "This page cannot show alerts; the tab title flashes when work finishes.");
  const list = h("div", { class: "list" });
  const draw = () => {
    const rows = jobs.all();
    list.replaceChildren(...(rows.length ? rows.map(jobRow) : [h("p", { class: "muted" }, "Nothing has run yet.")]));
  };
  draw();
  app.cleanup = jobs.subscribe(() => draw());
  const node = h("div", {},
    h("div", { class: "card" }, h("b", {}, "Tell me when work finishes"), status,
      h("button", { class: "btn full", onclick: async () => { status.textContent = await notify.enable(); } }, "Turn on alerts")),
    list);
  return { title: "Work", node, back: "#/" };
}

function resultView(j) {
  const r = j.result || {};
  const sid = j.subject;
  const added = (r.added || []).map((a) => ({ ...a, kind: /\.glb$/i.test(a.path) ? "mesh" : "still", state: "pending", mtime: 0 }));
  const failed = (r.checks || []).filter((c) => c.pass === false || c.ok === false);
  return h("div", { class: "card" },
    h("b", {}, j.status === "done" ? "Finished" : "It did not pass"),
    r.adjusted ? h("p", { class: "small muted" }, "Used your adjusted settings.") : null,
    failed.length ? h("ul", { class: "small" }, failed.map((c) => h("li", {}, c.note || c.why || c.text || c.check || "a check"))) : null,
    added.length && sid ? [h("p", { class: "small" }, "New - open each to approve or reject:"), h("div", { class: "thumbs" }, added.map((a) => thumb(a, sid, j.step)))] : null);
}

export async function jobView({ params }) {
  const id = params[0];
  if (!app.subjects) await loadSubjects();
  let job = jobs.byId(id) && jobs.byId(id).events && jobs.byId(id).events.length ? jobs.byId(id) : await jobs.load(id);
  if (!job) return { title: "Work", node: errorBox({ error: "This work is no longer listed." }), back: "#/jobs" };
  const head = h("div"), bar = h("div"), result = h("div"), actions = h("div");
  const log = h("pre", { class: "log" });
  const tech = h("div");
  function draw(j) {
    job = j;
    head.replaceChildren(h("div", { class: "row between" }, h("div", {}, h("b", {}, actionLabel(j.cmd)), h("div", { class: "small muted" }, `${j.subject ? subjectName(j.subject) + " - " : ""}${when(j.created)}`)),
      h("span", { class: "badge " + j.status }, jobWord(j.status))));
    bar.replaceChildren(h("p", {}, j.stage || "Waiting"), h("div", { class: "bar" }, h("div", { style: { width: `${j.pct}%` } })));
    log.textContent = (j.events || []).filter((e) => e.kind === "log" || e.kind === "stage").map((e) => (e.kind === "stage" ? "== " : "") + e.msg).join("\n");
    tech.replaceChildren(techRows([["command", j.cmd], ["job", j.id], ["step", j.step || "-"], ["settings", j.args || {}], j.result ? ["result", j.result] : null]));
    result.replaceChildren(...[j.error ? errorBox({ error: j.error }) : null, !jobs.isActive(j) && j.result ? resultView(j) : null].filter(Boolean));
    actions.replaceChildren(...[
      jobs.isActive(j) ? h("button", { class: "btn bad full", onclick: () => jobs.cancel(j.id) }, "Cancel") : null,
      j.subject && j.step ? h("a", { class: "btn primary full", href: `#/s/${j.subject}/step/${j.step}`, style: { marginTop: "8px" } }, "Back to the step") : null,
      !jobs.isActive(j) && j.subject && j.step && command(j.cmd) && j.cmd !== "export" ? h("button", { class: "btn full", style: { marginTop: "8px" }, onclick: async () => { const n = await jobs.start(j.cmd, j.subject, j.args || {}, { step: j.step }); if (n) go(`#/job/${n.id}`); } }, "Run again") : null].filter(Boolean));
  }
  draw(job);
  app.cleanup = jobs.subscribe((j) => { if (j && j.id === id) draw(jobs.byId(id)); });
  if (jobs.isActive(job)) jobs.load(id);
  const node = h("div", {}, h("div", { class: "card" }, head, bar), result, actions,
    details("Details", tech, log),
    h("p", { class: "small muted" }, "This runs on the PC. You can leave or reload; it keeps going."));
  return { title: actionLabel(job.cmd), node, back: job.subject && job.step ? `#/s/${job.subject}/step/${job.step}` : "#/jobs" };
}
