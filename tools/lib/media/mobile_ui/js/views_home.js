// Home picker, type lists, new subject, coverage.
import { get, post } from "./api.js";
import { app, go, loadSubjects } from "./state.js";
import { errorBox, h, toast, when } from "./ui.js";
import { human } from "./subject_ui.js";

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
    h("div", { class: "grow" }, h("b", {}, s.name), h("small", {}, `${human(s.type)} - ${when(s.updated)}`)),
    s.hard ? h("span", { class: "chip hard" }, "Needs a redo") : s.soft ? h("span", { class: "chip soft" }, "Might need a look") : null,
    s.pending ? h("span", { class: "badge pending" }, `${s.pending} to OK`) : null);
}

// Everything waiting on you, across subjects: pictures to OK and steps ready to approve.
async function needsYou(list) {
  const waiting = list.filter((s) => s.pending);
  const shows = await Promise.all(waiting.slice(0, 12).map((s) => get(`/subjects/${s.id}`)));
  const rows = [];
  for (const r of shows) {
    if (!r.ok) continue;
    const doc = r.data.subject;
    for (const st of r.data.steps) {
      if (st.status !== "needs_ok" || !st.available) continue;
      const first = r.data.stills.find((x) => x.step === st.id && x.state === "pending");
      rows.push(h("a", { class: "item", href: first ? `#/s/${doc.id}/step/${st.id}/pic?path=${encodeURIComponent(first.path)}` : `#/s/${doc.id}/step/${st.id}` },
        h("div", { class: "grow" }, h("b", {}, doc.name), h("small", {}, `${st.label}: ${st.pending} waiting for your OK`)), h("span", { class: "chip st-needs_ok" }, "Needs your OK")));
    }
    const loose = r.data.stills.filter((x) => !x.step && x.state === "pending").length;
    if (loose) rows.push(h("a", { class: "item", href: `#/s/${doc.id}` }, h("div", { class: "grow" }, h("b", {}, doc.name), h("small", {}, `${loose} picture${loose === 1 ? "" : "s"} not on a step`))));
  }
  return rows;
}

export async function home() {
  const [subs, cov] = await Promise.all([loadSubjects(), get("/coverage")]);
  if (!subs.ok) return { title: "Pipeline Studio", node: errorBox(subs.data) };
  const list = app.subjects;
  const count = (t) => list.filter((s) => s.type === t).length;
  const recent = [...list].sort((a, b) => String(b.updated).localeCompare(String(a.updated))).slice(0, 6);
  const queue = await needsYou(list);
  const node = h("div", {},
    queue.length ? [h("h2", {}, "Needs your OK"), h("div", { class: "list" }, queue)] : null,
    h("h2", {}, "What do you want to work on?"),
    h("div", { class: "grid" }, app.info.types.map((t) =>
      h("a", { class: "tile", href: `#/type/${t}` }, h("b", {}, human(t)), h("span", { class: "meta" }, TYPE_NOTE[t] || ""), h("span", { class: "meta" }, `${count(t)} so far`)))),
    h("div", { class: "btn-row", style: { marginTop: "12px" } },
      h("a", { class: "btn primary", href: "#/new/character?ref=1" }, "Start from a reference"),
      h("a", { class: "btn", href: "#/jobs" }, "Work on the PC")),
    recent.length ? [h("h3", {}, "Recent"), h("div", { class: "list" }, recent.map(subjectRow))] : h("p", { class: "muted" }, "Nothing yet. Pick a type to start."),
    cov.ok ? h("p", { class: "small muted" }, `${cov.data.open} game slots are open. See Coverage.`) : null);
  return { title: "Pipeline Studio", node, tab: "home" };
}

export async function typeList({ params }) {
  const type = params[0];
  if (!app.info.types.includes(type)) return { title: "Not found", node: errorBox({ error: "That type does not exist." }) };
  await loadSubjects();
  const rows = app.subjects.filter((s) => s.type === type);
  const node = h("div", {},
    h("div", { class: "btn-row" },
      h("a", { class: "btn primary", href: `#/new/${type}` }, `New ${human(type).toLowerCase()}`),
      h("a", { class: "btn", href: `#/new/${type}?ref=1` }, "From a reference")),
    rows.length ? h("div", { class: "list" }, rows.map(subjectRow)) : h("p", { class: "muted" }, "None yet."));
  return { title: human(type), node, tab: "home", back: "#/" };
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
  const template = h("select", {}, h("option", { value: "" }, "Brand new"), same.map((s) => h("option", { value: s.id }, `A copy of ${s.name}`)));
  const err = h("div");
  const sync = () => { idHint.textContent = `Saved as: ${id.value.trim() || slug(name.value) || "-"}`; };
  name.addEventListener("input", sync); id.addEventListener("input", sync); sync();
  const submit = h("button", { class: "btn primary full", type: "submit" }, "Create");
  const form = h("form", { class: "card", onsubmit: async (e) => {
    e.preventDefault();
    if (!name.value.trim()) { err.replaceChildren(errorBox({ error: "Give it a name first." })); name.focus(); return; }
    submit.disabled = true;
    const res = await post("/subjects", { type, name: name.value.trim(), id: id.value.trim() || null, template: template.value || null });
    submit.disabled = false;
    if (!res.ok) { err.replaceChildren(errorBox(res.data)); return; }
    const sid = res.data.subject.id;
    toast(`Created ${res.data.subject.name}`);
    go(`#/s/${sid}/step/start`);
  } },
  reserved ? h("p", { class: "note-box small" }, "That one is the live model. Pick a new name.") : null,
  h("label", { class: "field" }, h("span", {}, "Name"), name),
  h("label", { class: "field" }, h("span", {}, "Start from"), template),
  h("details", { class: "card details" }, h("summary", {}, "Details"), h("label", { class: "field" }, h("span", {}, "Saved as (optional)"), id, idHint)),
  err, submit);
  setTimeout(() => name.focus(), 50);
  return { title: `New ${human(type).toLowerCase()}`, node: form, tab: "home", back: `#/type/${type}` };
}

// What Build still has to make: model setups, then each type's steps with actions not set up.
const SETUP_WORD = { ready: "Ready", partial: "Partly ready", missing: "Not built" };

function leftToBuild() {
  const reg = app.info.registry;
  const setups = Object.entries(reg.setups);
  const off = Object.entries(reg.actions).filter(([, a]) => !a.wired);
  const types = Object.entries(reg.types).map(([t, spec]) => {
    const rows = spec.steps.map((st) => ({ st, gaps: st.actions.filter(missing) })).filter((r) => r.gaps.length || r.st.open);
    return { t, rows };
  }).filter((x) => x.rows.length);
  const word = (id) => reg.actions[id].label;
  // Wired status, not this mode's: practice mode runs everything, but the list is what real mode lacks.
  function missing(a) { return !a.wired || (a.recipe && !reg.recipes_ready.includes(a.recipe)); }
  return h("div", {},
    h("p", { class: "small muted" }, app.info.simulated
      ? "Practice mode runs all of these with made-up results. In real mode each one says “Not set up yet” until it is built."
      : "Each of these says “Not set up yet” until it is built. Practice mode runs them with made-up results."),
    h("h3", {}, `Model setups (${setups.filter(([, s]) => s.status !== "ready").length} to build)`),
    h("div", { class: "list" }, setups.map(([id, s]) => h("div", { class: "item" },
      h("div", { class: "grow" }, h("b", {}, s.label), h("small", {}, s.models)),
      h("span", { class: "badge " + (s.status === "ready" ? "approved" : s.status === "partial" ? "pending" : "rejected") }, SETUP_WORD[s.status])))),
    h("h3", {}, `Actions not set up (${off.length})`),
    h("div", { class: "list" }, off.map(([id, a]) => h("details", { class: "item block" }, h("summary", {}, h("b", {}, a.label)),
      h("p", { class: "small" }, a.inputs ? `Uses: ${a.inputs}` : ""), h("p", { class: "small muted" }, a.setup ? `Setup: ${reg.setups[a.setup].label}` : "No model needed")))),
    h("h3", {}, "By type"),
    types.map(({ t, rows }) => h("details", { class: "card" }, h("summary", {}, `${human(t)} (${rows.length} step${rows.length === 1 ? "" : "s"})`),
      h("ul", { class: "small" }, rows.map(({ st, gaps }) => h("li", {}, h("b", {}, human(st.id)), ": ",
        gaps.length ? gaps.map((g) => word(g.id) + (g.wired ? " (needs its default recipe)" : "")).join(", ") : "",
        st.open ? h("span", { class: "muted" }, (gaps.length ? ". " : "") + "Still to decide: " + st.open) : null))))));
}

export async function coverage({ query }) {
  const show = query.show === "build" ? "build" : "slots";
  const seg = h("div", { class: "seg" }, [["slots", "Game slots"], ["build", "Left to build"]].map(([v, l]) =>
    h("button", { class: v === show ? "on" : "", onclick: () => go(v === "build" ? "#/coverage?show=build" : "#/coverage") }, l)));
  if (show === "build") return { title: "Coverage", node: h("div", {}, seg, h("div", { style: { height: "8px" } }), leftToBuild()), tab: "coverage" };
  const res = await get("/coverage");
  if (!res.ok) return { title: "Coverage", node: errorBox(res.data), tab: "coverage" };
  const cov = res.data;
  const types = [...new Set(cov.missing.map((s) => s.type))].sort();
  let filter = query.type || "", text = "";
  const listEl = h("div", { class: "list" });
  const search = h("input", { type: "text", placeholder: "Search", oninput: () => { text = search.value.trim().toLowerCase(); draw(); } });
  const chips = h("div", { class: "row" });
  function drawChips() {
    chips.replaceChildren(...["", ...types].map((t) => h("button", { class: "chip" + (t === filter ? " link" : ""), onclick: () => { filter = t; drawChips(); draw(); } },
      t ? `${human(t)} (${cov.missing.filter((s) => s.type === t).length})` : `All (${cov.missing.length})`)));
  }
  function draw() {
    const rows = cov.missing.filter((s) => (!filter || s.type === filter) && (!text || s.id.includes(text)));
    listEl.replaceChildren(...rows.slice(0, 300).map((s) => h("a", {
      class: "item", href: s.subject ? `#/s/${s.id}` : `#/new/${s.type}?name=${encodeURIComponent(s.id)}&id=${encodeURIComponent(s.id)}`,
    }, h("div", { class: "grow" }, h("b", {}, human(s.id)), h("small", {}, human(s.type))),
      s.subject ? h("span", { class: "badge pending" }, "In progress") : h("span", { class: "badge" }, "Start"))),
    rows.length > 300 ? h("p", { class: "muted" }, `${rows.length - 300} more; search to narrow.`) : null);
  }
  drawChips(); draw();
  const done = cov.slots - cov.open;
  const node = h("div", {}, seg, h("div", { style: { height: "8px" } }),
    h("div", { class: "card" },
      h("div", { class: "row between" }, h("b", {}, `${done} of ${cov.slots} game slots done`), cov.simulated ? h("span", { class: "chip sim" }, "Practice") : null),
      h("div", { class: "bar", style: { marginTop: "8px" } }, h("div", { style: { width: `${cov.slots ? (100 * done) / cov.slots : 0}%` } })),
      h("p", { class: "small muted" }, "A slot is something the game uses today. It is done when one made here is sent to the game. Tap one to open or start it.")),
    search, chips, h("div", { style: { height: "8px" } }), listEl);
  return { title: "Coverage", node, tab: "coverage" };
}
