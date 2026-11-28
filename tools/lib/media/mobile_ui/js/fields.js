// Plain form for a section's data: text, numbers, yes/no, lists and nested groups.
// Editing as raw text stays behind "Edit as text" in Details.
import { h, toast } from "./ui.js";
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
