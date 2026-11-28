// Plain form for a section's data: text, numbers, yes/no, lists and nested groups.
// Editing as raw text stays behind "Edit as text" in Details.
import { h, toast } from "./ui.js";
import { app } from "./state.js";
import { human } from "./subject_ui.js";

function leaf(key, value, readOnly, onChange) {
  const lab = (el) => h("label", { class: "field" }, h("span", {}, human(key)), el);
  if (typeof value === "boolean") {
    const el = h("input", { type: "checkbox", disabled: readOnly, onchange: onChange }); el.checked = value;
    return { el: h("label", { class: "check" }, el, h("span", {}, human(key))), read: () => el.checked };
  }
  if (typeof value === "number") {
    const el = h("input", { type: "number", step: "any", value: String(value), disabled: readOnly, onchange: onChange });
    return { el: lab(el), read: () => (el.value === "" ? 0 : Number(el.value)) };
  }
  if (Array.isArray(value) && value.every((v) => typeof v !== "object" || v === null)) {
    const el = h("input", { type: "text", value: value.join(", "), placeholder: "Separate with commas", disabled: readOnly, onchange: onChange });
    const nums = value.length && value.every((v) => typeof v === "number");
    return { el: lab(el), read: () => el.value.split(",").map((s) => s.trim()).filter(Boolean).map((s) => (nums && !isNaN(Number(s)) ? Number(s) : s)) };
  }
  if (value && typeof value === "object" && !Array.isArray(value)) {
    const inner = group(value, readOnly, onChange);
    return { el: h("fieldset", { class: "group" }, h("legend", {}, human(key)), inner.el), read: inner.read };
  }
  if (Array.isArray(value)) {
    return { el: lab(h("div", { class: "muted small" }, `${value.length} entries (edit as text in Details)`)), read: () => value };
  }
  const long = String(value ?? "").length > 60;
  const el = h(long ? "textarea" : "input", { type: "text", disabled: readOnly, onchange: onChange });
  el.value = value ?? "";
  return { el: lab(el), read: () => el.value };
}

function group(data, readOnly, onChange) {
  const parts = Object.entries(data).map(([k, v]) => [k, leaf(k, v, readOnly, onChange)]);
  return { el: h("div", {}, parts.map(([, p]) => p.el)), read: () => Object.fromEntries(parts.map(([k, p]) => [k, p.read()])) };
}

// Returns {node, read, setData, details}: `details` is the edit-as-text block for a Details toggle.
export function fieldsEditor(initial, { readOnly = false, onChange = () => {} } = {}) {
  let data = JSON.parse(JSON.stringify(initial || {}));
  const box = h("div");
  let current;
  const draw = () => {
    current = group(data, readOnly, onChange);
    box.replaceChildren(Object.keys(data).length ? current.el : h("p", { class: "muted" }, readOnly ? "Nothing filled in." : "Nothing here yet. Add something below."));
  };
  draw();
  const read = () => (current ? current.read() : data);
  const newKey = h("input", { type: "text", placeholder: "What is it called?" });
  const newKind = h("select", {}, [["text", "Text"], ["number", "Number"], ["yes/no", "Yes or no"], ["list", "List"]].map(([v, l]) => h("option", { value: v }, l)));
  const add = readOnly ? null : h("details", { class: "card" }, h("summary", {}, "Add something"), newKey, h("div", { style: { height: "8px" } }), newKind,
    h("div", { style: { height: "8px" } }),
    h("button", { class: "btn full", onclick: () => {
      const k = newKey.value.trim().toLowerCase().replace(/\s+/g, "_");
      if (!k) return toast("Give it a name");
      data = read();
      if (k in data) return toast("That already exists");
      data[k] = { text: "", number: 0, "yes/no": false, list: [] }[newKind.value];
      newKey.value = ""; draw(); onChange();
    } }, "Add"));
  const raw = h("textarea", { class: "mono", rows: 8, disabled: readOnly });
  const err = h("div", { class: "small" });
  const details = h("div", {}, h("p", { class: "small muted" }, "Edit as text"), raw, err,
    readOnly ? null : h("button", { class: "btn full", onclick: () => {
      try { data = JSON.parse(raw.value); } catch (e) { err.textContent = "That text does not read correctly: " + e.message; return; }
      err.textContent = ""; draw(); onChange(); toast("Updated");
    } }, "Use this text"));
  const syncRaw = () => { raw.value = JSON.stringify(read(), null, 2); };
  syncRaw();
  details.addEventListener("toggle", syncRaw, true);
  return { node: h("div", {}, box, add), read, details, syncRaw };
}

// Typed form from the step's field list (the studio registry): plain labels, help, presets.
// Keys the list does not name are kept as they are and stay editable as text in Details.
const blank = (f) => (f.default !== undefined && f.default !== null ? JSON.parse(JSON.stringify(f.default)) : f.kind === "multi" || f.kind === "list" || f.kind === "table" ? [] : f.kind === "group" ? {} : f.kind === "bool" ? false : "");

function typed(f, value, readOnly, onChange) {
  const v = value === undefined ? blank(f) : value;
  const word = (o) => (f.labels || {})[o] || human(o);
  const wrap = (el, cls = "field") => h("div", { class: cls }, h("span", {}, f.label + (f.required ? "" : " (optional)")), f.help ? h("small", { class: "help" }, f.help) : null, el);
  if (f.kind === "bool") {
    const el = h("input", { type: "checkbox", disabled: readOnly, onchange: onChange }); el.checked = !!v;
    return { el: h("label", { class: "check" }, el, h("span", {}, f.label), f.help ? h("small", { class: "help" }, " " + f.help) : null), read: () => el.checked };
  }
  if (f.kind === "number") {
    const el = h("input", { type: "number", inputmode: "decimal", step: f.step ?? "any", min: f.min ?? "", max: f.max ?? "", value: v === "" ? "" : String(v), disabled: readOnly, onchange: onChange });
    const range = f.min !== undefined && f.max !== undefined ? h("small", { class: "help" }, `From ${f.min} to ${f.max}`) : null;
    return { el: wrap(h("div", {}, el, range)), read: () => (el.value === "" ? null : Number(el.value)) };
  }
  if (f.kind === "choice") {
    const el = h("select", { disabled: readOnly, onchange: onChange }, h("option", { value: "" }, "Pick one"), (f.options || []).map((o) => h("option", { value: o }, word(o))));
    el.value = v ?? "";
    return { el: wrap(el), read: () => el.value };
  }
  if (f.kind === "subject") {
    // One of the subjects already made, of the types the field allows.
    const pool = (app.subjects || []).filter((s) => (f.of || []).includes(s.type));
    const el = h("select", { disabled: readOnly, onchange: onChange }, h("option", { value: "" }, pool.length ? "None" : "None made yet"),
      pool.map((s) => h("option", { value: s.id }, s.name)),
      v && !pool.some((s) => s.id === v) ? h("option", { value: v }, v) : null);
    el.value = v ?? "";
    return { el: wrap(el), read: () => el.value };
  }
  if (f.kind === "multi") {
    const on = new Set(Array.isArray(v) ? v : []);
    const box = h("div", { class: "chips-pick" }, (f.options || []).map((o) => {
      const b = h("button", { type: "button", class: "chip" + (on.has(o) ? " on" : ""), disabled: readOnly, "aria-pressed": String(on.has(o)), onclick: () => {
        if (on.has(o)) on.delete(o); else on.add(o);
        b.classList.toggle("on", on.has(o)); b.setAttribute("aria-pressed", String(on.has(o))); onChange();
      } }, word(o));
      return b;
    }));
    return { el: wrap(box), read: () => (f.options || []).filter((o) => on.has(o)).concat([...on].filter((o) => !(f.options || []).includes(o))) };
  }
  if (f.kind === "color") {
    const el = h("input", { type: "color", value: /^#[0-9a-f]{6}$/i.test(v) ? v : "#808080", disabled: readOnly, onchange: onChange });
    const set = h("input", { type: "checkbox", disabled: readOnly, onchange: onChange }); set.checked = !!v;
    return { el: wrap(h("div", { class: "row" }, el, h("label", { class: "check" }, set, h("span", {}, "Use this colour")))), read: () => (set.checked ? el.value : "") };
  }
  if (f.kind === "list") {
    const el = h("textarea", { rows: 3, placeholder: "One per line", disabled: readOnly, onchange: onChange });
    el.value = (Array.isArray(v) ? v : []).join("\n");
    return { el: wrap(el), read: () => el.value.split("\n").map((s) => s.trim()).filter(Boolean) };
  }
  if (f.kind === "group") {
    const parts = (f.fields || []).map((c) => [c.key, typed(c, (v || {})[c.key], readOnly, onChange)]);
    return { el: h("fieldset", { class: "group" }, h("legend", {}, f.label), f.help ? h("small", { class: "help" }, f.help) : null, parts.map(([, p]) => p.el)),
      read: () => Object.fromEntries(parts.map(([k, p]) => [k, p.read()])) };
  }
  if (f.kind === "table") {
    const rows = [];
    const list = h("div", { class: "table-rows" });
    const addRow = (val) => {
      const parts = (f.columns || []).map((c) => [c.key, typed({ ...c, required: true }, (val || {})[c.key], readOnly, onChange)]);
      const row = { parts };
      row.el = h("div", { class: "table-row card" }, parts.map(([, p]) => p.el),
        readOnly ? null : h("button", { type: "button", class: "btn ghost small-btn", onclick: () => { rows.splice(rows.indexOf(row), 1); row.el.remove(); onChange(); } }, "Remove"));
      rows.push(row); list.append(row.el);
    };
    (Array.isArray(v) ? v : []).forEach(addRow);
    const add = readOnly ? null : h("button", { type: "button", class: "btn full", onclick: () => { addRow({}); onChange(); } }, `Add to ${f.label.toLowerCase()}`);
    return { el: h("fieldset", { class: "group" }, h("legend", {}, f.label + (f.required ? "" : " (optional)")), f.help ? h("small", { class: "help" }, f.help) : null, list, add),
      read: () => rows.map((r) => Object.fromEntries(r.parts.map(([k, p]) => [k, p.read()]))) };
  }
  const el = h(f.kind === "long" ? "textarea" : "input", { type: "text", rows: 3, disabled: readOnly, onchange: onChange });
  el.value = v ?? "";
  return { el: wrap(el), read: () => el.value.trim() };
}

export function schemaEditor(fields, initial, { readOnly = false, onChange = () => {} } = {}) {
  let data = JSON.parse(JSON.stringify(initial || {}));
  const box = h("div");
  let parts = [];
  const known = new Set(fields.map((f) => f.key));
  const draw = () => {
    parts = fields.map((f) => [f.key, typed(f, data[f.key], readOnly, onChange)]);
    box.replaceChildren(...parts.map(([, p]) => p.el));
  };
  draw();
  const read = () => ({ ...Object.fromEntries(Object.entries(data).filter(([k]) => !known.has(k))), ...Object.fromEntries(parts.map(([k, p]) => [k, p.read()])) });
  const raw = h("textarea", { class: "mono", rows: 8, disabled: readOnly });
  const err = h("div", { class: "small" });
  const details = h("div", {}, raw, err,
    readOnly ? null : h("button", { class: "btn full", onclick: () => {
      try { data = JSON.parse(raw.value); } catch (e) { err.textContent = "That text does not read correctly: " + e.message; return; }
      err.textContent = ""; draw(); onChange(); toast("Updated");
    } }, "Use this text"));
  const syncRaw = () => { raw.value = JSON.stringify(read(), null, 2); };
  syncRaw();
  return { node: box, read, details, syncRaw };
}
