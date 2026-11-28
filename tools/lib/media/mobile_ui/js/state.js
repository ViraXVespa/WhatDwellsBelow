// Shared page state: server info (types, sections, commands, roles) and small caches.
import { get } from "./api.js";

export const app = {
  info: null,
  subjects: null,     // last /subjects list
  cleanup: null,      // set by a screen; runs when the route changes
  beforeLeave: null,  // set by a screen with unsaved edits; awaited before the route changes
};

export async function loadInfo() {
  const res = await get("/info");
  if (res.ok) app.info = res.data;
  return res;
}

export async function loadSubjects() {
  const res = await get("/subjects");
  if (res.ok) app.subjects = res.data.subjects;
  return res;
}

export const go = (hash) => { location.hash = hash; };
export const command = (cmd) => (app.info && app.info.commands[cmd]) || null;
