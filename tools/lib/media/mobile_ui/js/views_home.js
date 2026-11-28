// Home picker, type lists, new subject, coverage.
import { get, post } from "./api.js";
import { app, go, loadSubjects } from "./state.js";
import { cap, errorBox, h, showError, toast, when } from "./ui.js";

const TYPE_NOTE = {
  character: "Mannequin first, then model, customization, animation",
  npc: "Town people, portraits, dialog",
  enemy: "Equipped design, behavior, stats, variants",
  "sub-boss": "Enemy rules at a 2x source", boss: "Enemy rules at a 4x source",
  equipment: "Skins, skills, offsets, stats", item: "Art and stats", projectile: "Art and motion",
  decoration: "Props", resource: "Nodes and piles", ui: "Plates and icons", biome: "Overview, features, art, layout",
  building: "Art and dimensions", vfx: "Effect bursts",
};

function subjectRow(s) {
  return h("a", { class: "item", href: `#/s/${s.id}` },
    h("div", { class: "grow" }, h("b", {}, s.name), h("small", {}, `${s.type} - ${s.id} - ${when(s.updated)}`)),
    s.hard ? h("span", { class: "chip hard" }, `${s.hard} hard`) : null,
    s.soft ? h("span", { class: "chip soft" }, `${s.soft} soft`) : null,
    s.pending ? h("span", { class: "badge pending" }, `${s.pending} to review`) : null);
}

export async function home() {
  const [subs, cov] = await Promise.all([loadSubjects(), get("/coverage")]);
  if (!subs.ok) return { title: "Pipeline Studio", node: errorBox(subs.data) };
  const list = app.subjects;
  const count = (t) => list.filter((s) => s.type === t).length;
  const pending = list.reduce((n, s) => n + (s.pending || 0), 0);
  const recent = [...list].sort((a, b) => String(b.updated).localeCompare(String(a.updated))).slice(0, 6);
  const node = h("div", {},
    h("h2", {}, "What do you want to work on?"),
    h("div", { class: "grid" }, app.info.types.map((t) =>
      h("a", { class: "tile", href: `#/type/${t}` }, h("b", {}, cap(t)), h("span", { class: "meta" }, TYPE_NOTE[t] || ""), h("span", { class: "meta" }, `${count(t)} subject${count(t) === 1 ? "" : "s"}`)))),
    h("div", { class: "btn-row", style: { marginTop: "12px" } },
      h("a", { class: "btn primary", href: "#/new/character?ref=1" }, "Start from a reference"),
      h("a", { class: "btn", href: "#/preview" }, pending ? `Review ${pending} still${pending === 1 ? "" : "s"}` : "Preview"),
      h("a", { class: "btn", href: "#/coverage" }, cov.ok ? `${cov.data.open} open slots` : "Coverage")),
    recent.length ? [h("h3", {}, "Recent"), h("div", { class: "list" }, recent.map(subjectRow))] : h("p", { class: "muted" }, "No subjects yet. Pick a type to start one."));
  return { title: "Pipeline Studio", node, tab: "home" };
}

export async function typeList({ params }) {
  const type = params[0];
  if (!app.info.types.includes(type)) return { title: "Unknown type", node: errorBox({ error: `No subject type ${type}` }) };
  await loadSubjects();
  const rows = app.subjects.filter((s) => s.type === type);
  const node = h("div", {},
    h("div", { class: "btn-row" },
      h("a", { class: "btn primary", href: `#/new/${type}` }, `New ${type}`),
      h("a", { class: "btn", href: `#/new/${type}?ref=1` }, "From a reference")),
    rows.length ? h("div", { class: "list" }, rows.map(subjectRow)) : h("p", { class: "muted" }, `No ${type} subjects yet.`));
  return { title: cap(type), node, tab: "home", back: "#/" };
}

const slug = (s) => s.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 64);

export async function newSubject({ params, query }) {
  const type = params[0];
  await loadSubjects();
  const same = app.subjects.filter((s) => s.type === type);
  // The live female model is never a default id; a coverage tap on it starts a blank form.
  const reserved = [query.id, query.name].some((v) => v && slug(v) === "female");
  if (reserved) { delete query.id; delete query.name; }
  const name = h("input", { type: "text", placeholder: "Name (required)", autocomplete: "off", value: query.name || "" });
  const id = h("input", { type: "text", placeholder: "id", autocomplete: "off", autocapitalize: "off", value: query.id || "" });
  const idHint = h("span", { class: "small muted" });
  const template = h("select", {}, h("option", { value: "" }, "Brand new"), same.map((s) => h("option", { value: s.id }, `Copy ${s.name} (${s.id})`)));
  const err = h("div");
  const sync = () => { idHint.textContent = `id: ${id.value.trim() || slug(name.value) || "-"}`; };
  name.addEventListener("input", sync); id.addEventListener("input", sync); sync();
  const submit = h("button", { class: "btn primary full", type: "submit" }, "Create");
  const form = h("form", { class: "card", onsubmit: async (e) => {
    e.preventDefault();
    if (!name.value.trim()) { err.replaceChildren(errorBox({ error: "A name is required before anything else." })); name.focus(); return; }
    submit.disabled = true;
    const res = await post("/subjects", { type, name: name.value.trim(), id: id.value.trim() || null, template: template.value || null });
    submit.disabled = false;
    if (!res.ok) { err.replaceChildren(errorBox(res.data)); return; }
    const sid = res.data.subject.id;
    toast(`Created ${sid}`);
    if (query.ref) go(`#/s/${sid}/ref`);
    else if (template.value) go(`#/s/${sid}`);
    else go(`#/s/${sid}/sec/details?flow=1`);
  } },
  reserved ? h("p", { class: "note-box small" }, "The female slot is the live model; pick a new name and id for this subject.") : null,
  h("label", { class: "field" }, h("span", {}, "Name"), name),
  h("label", { class: "field" }, h("span", {}, "Id (optional; the name's slug when empty)"), id, idHint),
  h("label", { class: "field" }, h("span", {}, "Start from"), template),
  err, submit);
  setTimeout(() => name.focus(), 50);
  return { title: query.ref ? `New ${type} from a reference` : `New ${type}`, node: form, tab: "home", back: `#/type/${type}` };
}

export async function coverage({ query }) {
  const res = await get("/coverage");
  if (!res.ok) return { title: "Coverage", node: errorBox(res.data), tab: "coverage" };
  const cov = res.data;
  const types = [...new Set(cov.missing.map((s) => s.type))].sort();
  let filter = query.type || "", text = "";
  const listEl = h("div", { class: "list" });
  const search = h("input", { type: "text", placeholder: "Search open slots", oninput: () => { text = search.value.trim().toLowerCase(); draw(); } });
  const chips = h("div", { class: "row" });
  function drawChips() {
    chips.replaceChildren(...["", ...types].map((t) => h("button", { class: "chip" + (t === filter ? " link" : ""), onclick: () => { filter = t; drawChips(); draw(); } },
      t ? `${t} (${cov.missing.filter((s) => s.type === t).length})` : `all (${cov.missing.length})`)));
  }
  function draw() {
    const rows = cov.missing.filter((s) => (!filter || s.type === filter) && (!text || s.id.includes(text)));
    listEl.replaceChildren(...rows.slice(0, 300).map((s) => h("a", {
      class: "item", href: s.subject ? `#/s/${s.id}` : `#/new/${s.type}?name=${encodeURIComponent(s.id)}&id=${encodeURIComponent(s.id)}`,
    }, h("div", { class: "grow" }, h("b", {}, s.id), h("small", { class: "mono" }, s.source)),
      h("span", { class: "badge" }, s.type), s.subject ? h("span", { class: "badge pending" }, "in progress") : h("span", { class: "badge" }, "start"))),
    rows.length > 300 ? h("p", { class: "muted" }, `${rows.length - 300} more; search to narrow.`) : null);
  }
  drawChips(); draw();
  const done = cov.slots - cov.open;
  const node = h("div", {},
    h("div", { class: "card" },
      h("div", { class: "row between" }, h("b", {}, `${done} of ${cov.slots} live slots exported`), cov.simulated ? h("span", { class: "chip sim" }, "simulated export index") : null),
      h("div", { class: "bar", style: { marginTop: "8px" } }, h("div", { style: { width: `${cov.slots ? (100 * done) / cov.slots : 0}%` } })),
      h("p", { class: "small muted" }, "A slot is a live sprite, NPC line or gear id the game uses today. It closes when a pipeline export with that id lands. Tap one to open or start its subject.")),
    search, chips, h("div", { style: { height: "8px" } }), listEl);
  return { title: "Coverage", node, tab: "coverage" };
}
