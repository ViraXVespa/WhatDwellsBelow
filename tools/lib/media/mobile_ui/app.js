
const $ = (id) => document.getElementById(id);

const state = { facing:"front", prompt:"", style:0.7, seed:-1, steps:20, cfg:7, clips:[] };
let abortCtrl = null;
let generating = false;
const MAX_LOG = 200;
const STORAGE_KEY = "wdb-character-ui";
const MORE_KEY = "wdb-more-open";

function savePicks(picks) {
  fetch("/api/picks", { method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify(picks) });
}
function saveLedger(entry) {
  fetch("/api/ledger", { method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify(entry) });
}

function persistForm() {
  const data = {
    prompt: $("prompt").value,
    negative: $("negative").value,
    style: $("style").value,
    seed: $("seed").value,
    steps: $("steps").value,
    cfg: $("cfg").value,
    name: $("name").value,
    ref: $("ref").value,
    pose: $("pose").value,
    facing: $("facing").value,
  };
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(data)); } catch (e) {}
}

function restoreForm() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    const data = JSON.parse(raw);
    if (data.prompt != null) $("prompt").value = data.prompt;
    if (data.negative != null) $("negative").value = data.negative;
    if (data.style != null) $("style").value = data.style;
    if (data.seed != null) $("seed").value = data.seed;
    if (data.steps != null) $("steps").value = data.steps;
    if (data.cfg != null) $("cfg").value = data.cfg;
    if (data.name != null) $("name").value = data.name;
    if (data.ref != null) $("ref").value = data.ref;
    if (data.pose != null) $("pose").value = data.pose;
    if (data.facing != null) $("facing").value = data.facing;
  } catch (e) {}
  updateGenerateButtons();
}

function updateGenerateButtons() {
  const empty = !$("prompt").value.trim();
  $("generate").disabled = empty || generating;
  $("generate-another").disabled = empty || generating;
}

function showToast(msg) {
  const t = $("toast");
  t.textContent = msg;
  t.classList.add("show");
  setTimeout(() => t.classList.remove("show"), 1800);
}

function haptic() {
  if (navigator.vibrate) navigator.vibrate(12);
}

function updateNextHint() {
  const el = $("next-hint");
  const empty = $("empty-hint");
  if (!el) return;
  const goods = state.clips.filter(c => c.mark === "good").length;
  const total = state.clips.length;
  if (empty) empty.hidden = total > 0;
  if (total === 0) { el.textContent = ""; return; }
  if (goods === 0) el.textContent = "Mark the ones you like as Good.";
  else if (goods < 3) el.textContent = `Nice — ${goods} Good so far. A few more and you can build a walk test.`;
  else el.textContent = "Looks good! You can build a walk test whenever you’re ready.";
}

function updateFacingReminder() {
  const el = $("facing-reminder");
  if (!el) return;
  const label = $("facing").options[$("facing").selectedIndex].text;
  const goods = state.clips.filter(c => c.mark === "good").length;
  el.textContent = `${label} · ${goods} Good`;
}

function updateReviewPrompt() {
  const el = $("review-prompt");
  if (!el) return;
  el.textContent = state.prompt ? state.prompt : "";
}

function updateSummary() {
  const el = $("summary-text");
  if (!el) return;
  const goods = state.clips.filter(c => c.mark === "good").length;
  const bads = state.clips.filter(c => c.mark === "bad").length;
  const total = state.clips.length;
  const label = $("facing").options[$("facing").selectedIndex].text;
  if (total === 0) {
    el.textContent = "No results yet";
  } else {
    el.textContent = `${label} · ${total} pictures · ${goods} Good · ${bads} Bad`;
  }
}

function appendLog(line) {
  const log = $("log");
  const lines = log.textContent.split("\n");
  lines.push(line);
  if (lines.length > MAX_LOG) lines.splice(0, lines.length - MAX_LOG);
  log.textContent = lines.join("\n");
  log.scrollTop = log.scrollHeight;
}

function setProgress(pct) {
  $("bar-fill").style.width = Math.max(0, Math.min(100, pct)) + "%";
}

function renderClips(clips) {
  const box = $("clips");
  box.innerHTML = "";
  clips.forEach((clip, i) => {
    const card = document.createElement("div");
    card.className = "clip";
    card.classList.toggle("good", clip.mark === "good");
    card.classList.toggle("bad", clip.mark === "bad");
    const src = clip.preview ? clip.preview + (clip.preview.includes("?") ? "&" : "?") + "t=" + Date.now() : "";
    card.innerHTML = `
      ${src ? `<img src="${src}" alt="result ${i + 1}" onerror="this.replaceWith(Object.assign(document.createElement('div'),{className:'placeholder',textContent:'Couldn’t load the picture'}))">` : `<div class="placeholder">Waiting for the first picture…</div>`}
      <div class="mark">
        <button data-i="${i}" data-mark="good" class="${clip.mark === "good" ? "chosen" : ""}" ${clip.mark === "good" ? "disabled" : ""}>Good</button>
        <button data-i="${i}" data-mark="bad" class="${clip.mark === "bad" ? "chosen" : ""}" ${clip.mark === "bad" ? "disabled" : ""}>Bad</button>
      </div>
      ${clip.mark ? `<button class="undo full" data-i="${i}">Undo</button>` : ""}
    `;
    box.appendChild(card);
  });
  box.querySelectorAll(".mark button").forEach(btn => {
    btn.onclick = () => {
      const i = +btn.dataset.i;
      state.clips[i].mark = btn.dataset.mark;
      savePicks(state.clips);
      renderClips(state.clips);
      updateNextHint();
      updateFacingReminder();
      updateSummary();
      haptic();
      showToast(btn.dataset.mark === "good" ? "Marked Good" : "Marked Bad");
    };
  });
  box.querySelectorAll(".undo").forEach(btn => {
    btn.onclick = () => {
      const i = +btn.dataset.i;
      state.clips[i].mark = null;
      savePicks(state.clips);
      renderClips(state.clips);
      updateNextHint();
      updateFacingReminder();
      updateSummary();
      showToast("Undone");
    };
  });
  updateNextHint();
  updateFacingReminder();
  updateReviewPrompt();
  updateSummary();
  if (clips.length) {
    const last = box.lastElementChild;
    if (last) last.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }
}

async function loadPicks() {
  try {
    const res = await fetch("/api/picks");
    const data = await res.json();
    if (Array.isArray(data) && data.length) {
      state.clips = data;
      $("prompt-section").hidden = true;
      $("review").hidden = false;
      renderClips(state.clips);
    } else {
      updateNextHint();
      updateSummary();
    }
  } catch (e) { updateNextHint(); updateSummary(); }
}

async function checkComfy() {
  const el = $("comfy-status");
  el.textContent = "Checking…";
  el.className = "status-pill";
  try {
    const res = await fetch("/comfy/system_stats", { method: "GET" });
    if (res.ok) {
      el.textContent = "Ready";
      el.className = "status-pill ok";
    } else {
      el.textContent = "Not ready";
      el.className = "status-pill bad";
    }
  } catch (e) {
    el.textContent = "Not running";
    el.className = "status-pill bad";
    el.title = "Tap to check again";
  }
}

function titleOf(node) {
  return ((node._meta && node._meta.title) || node.title || "").toLowerCase();
}

async function queuePrompt(payload) {
  const wfRes = await fetch("/workflow.json");
  const workflow = await wfRes.json();
  if (!workflow || Object.keys(workflow).length === 0) {
    throw new Error("The picture recipe is missing or empty. It must be the API-format JSON (not the UI graph).");
  }
  let pos = workflow["5"];
  let neg = workflow["6"];
  if (!pos || pos.class_type !== "CLIPTextEncode") {
    pos = null;
    for (const node of Object.values(workflow)) {
      if (node.class_type === "CLIPTextEncode" && node.inputs && "text" in node.inputs) {
        const t = titleOf(node);
        if (t.includes("positive")) { pos = node; break; }
        if (!pos) pos = node;
      }
    }
  }
  if (!neg || neg.class_type !== "CLIPTextEncode") {
    neg = null;
    for (const node of Object.values(workflow)) {
      if (node.class_type === "CLIPTextEncode" && node.inputs && "text" in node.inputs) {
        const t = titleOf(node);
        if (t.includes("negative")) { neg = node; break; }
      }
    }
  }
  if (pos && pos.inputs) pos.inputs.text = payload.prompt;
  if (neg && neg.inputs && payload.negative) neg.inputs.text = payload.negative;

  for (const node of Object.values(workflow)) {
    if (node.class_type === "KSampler" && node.inputs) {
      if ("seed" in node.inputs) node.inputs.seed = payload.seed;
      if ("steps" in node.inputs) node.inputs.steps = payload.steps;
      if ("cfg" in node.inputs) node.inputs.cfg = payload.cfg;
      if ("denoise" in node.inputs) node.inputs.denoise = payload.style;
    }
  }
  const res = await fetch("/comfy/prompt", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ prompt: workflow })
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error("Comfy: " + err.slice(0, 300));
  }
  const data = await res.json();
  return data.prompt_id;
}

async function pollResult(promptId) {
  for (let i = 0; i < 90; i++) {
    setProgress(Math.min(95, (i / 90) * 100));
    const res = await fetch(`/comfy/history/${promptId}`);
    const hist = await res.json();
    if (hist[promptId]) {
      const outputs = hist[promptId].outputs || {};
      for (const node of Object.values(outputs)) {
        if (node.images && node.images.length) {
          const img = node.images[0];
          setProgress(100);
          return `/comfy/view?filename=${encodeURIComponent(img.filename)}&subfolder=${encodeURIComponent(img.subfolder || "")}&type=${encodeURIComponent(img.type || "output")}`;
        }
      }
    }
    await new Promise(r => setTimeout(r, 1000));
  }
  setProgress(0);
  return null;
}

async function doGenerate(useNewSeed) {
  if (generating || !$("prompt").value.trim()) return;
  generating = true;
  updateGenerateButtons();
  persistForm();

  state.facing = $("facing").value;
  state.prompt = $("prompt").value;
  state.style = +$("style").value;
  let seed = +$("seed").value;
  if (useNewSeed || seed < 0) seed = Math.floor(Math.random() * 1e9);
  state.seed = seed;
  state.steps = +$("steps").value;
  state.cfg = +$("cfg").value;

  $("prompt-section").hidden = true;
  $("review").hidden = true;
  $("status").hidden = false;
  $("status-text").textContent = "Making the picture…";
  setProgress(0);
  $("log").textContent = "";

  const payload = {
    prompt: state.prompt,
    negative: $("negative").value,
    style: state.style,
    seed: seed,
    steps: state.steps,
    cfg: state.cfg,
    facing: state.facing,
  };

  try {
    const promptId = await queuePrompt(payload);
    const url = await pollResult(promptId);
    state.clips.push({ preview: url || "", mark: null });
    $("status").hidden = true;
    $("review").hidden = false;
    $("new").hidden = true;
    renderClips(state.clips);
    savePicks(state.clips);
  } catch (e) {
    const raw = e.message || "Something went wrong.";
    $("status-text").textContent = "Could not start the picture. Try again or ask for help.";
    appendLog(raw);
    setProgress(0);
  } finally {
    generating = false;
    updateGenerateButtons();
  }
}

async function streamAction(url, payload, label, doneMsg) {
  if (abortCtrl) abortCtrl.abort();
  abortCtrl = new AbortController();
  $("status").hidden = false;
  $("cancel").hidden = false;
  $("status-text").textContent = label;
  setProgress(5);
  $("log").textContent = "";
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload || {}),
      signal: abortCtrl.signal,
    });
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buf = "";
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });
      const lines = buf.split("\n");
      buf = lines.pop();
      for (const line of lines) {
        if (!line.trim()) continue;
        appendLog(line);
        $("status-text").textContent = line.slice(0, 80);
        setProgress(Math.min(95, (parseFloat($("bar-fill").style.width) || 5) + 2));
      }
    }
    setProgress(100);
    $("status-text").textContent = "Done";
    if (doneMsg) showToast(doneMsg);
  } catch (e) {
    if (e.name === "AbortError") {
      $("status-text").textContent = "Cancelled";
      fetch("/api/cancel", { method: "POST" });
    } else {
      $("status-text").textContent = "Something went wrong. Try again or ask for help.";
    }
    setProgress(0);
  } finally {
    $("cancel").hidden = true;
    abortCtrl = null;
  }
}

$("comfy-status").onclick = checkComfy;

$("start-comfy").onclick = async () => {
  $("start-comfy").disabled = true;
  showToast("Trying to start…");
  try {
    const res = await fetch("/api/start-comfy", { method: "POST" });
    const data = await res.json();
    if (data.status === "started" || data.status === "already-running") {
      showToast("Picture maker starting…");
      setTimeout(checkComfy, 3000);
    } else {
      showToast(data.message || "Couldn’t start it automatically");
    }
  } catch (e) {
    showToast("Couldn’t start it");
  } finally {
    $("start-comfy").disabled = false;
  }
};

$("cancel").onclick = () => {
  if (abortCtrl) abortCtrl.abort();
  fetch("/api/cancel", { method: "POST" });
};

$("back").onclick = () => {
  $("review").hidden = true;
  $("status").hidden = true;
  $("prompt-section").hidden = false;
  $("new").hidden = true;
};

$("new").onclick = () => {
  state.clips = [];
  $("prompt").value = "";
  persistForm();
  $("review").hidden = true;
  $("prompt-section").hidden = false;
  $("new").hidden = true;
  updateGenerateButtons();
  updateSummary();
  showToast("Ready for a new one");
};

$("clear-marks").onclick = () => {
  if (!confirm("Clear all marks on this set?")) return;
  state.clips.forEach(c => c.mark = null);
  savePicks(state.clips);
  renderClips(state.clips);
  showToast("Marks cleared");
};

$("copy-prompt").onclick = async () => {
  const text = $("review-prompt").textContent || "";
  try {
    await navigator.clipboard.writeText(text);
    showToast("Prompt copied");
  } catch (e) {
    showToast("Couldn’t copy");
  }
};

$("summary-toggle").onclick = () => {
  $("summary-flyout").hidden = !$("summary-flyout").hidden;
};
$("summary-close").onclick = () => {
  $("summary-flyout").hidden = true;
};

$("facing").addEventListener("change", () => {
  persistForm();
  updateFacingReminder();
  updateSummary();
});

$("prompt").addEventListener("input", updateGenerateButtons);
$("prompt").addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    doGenerate(false);
  }
});

$("more-options").addEventListener("toggle", () => {
  try { localStorage.setItem(MORE_KEY, $("more-options").open ? "1" : "0"); } catch (e) {}
});

$("generate").onclick = () => doGenerate(false);
$("generate-another").onclick = () => doGenerate($("new-seed").checked);

$("randomize").onclick = () => { $("seed").value = Math.floor(Math.random() * 1e9); persistForm(); };

function lockDecision() {
  $("approve").disabled = true;
  $("deny").disabled = true;
  setTimeout(() => {
    $("approve").disabled = false;
    $("deny").disabled = false;
  }, 1500);
}

$("approve").onclick = () => {
  lockDecision();
  saveLedger({ decision:"approve", facing:state.facing, at:new Date().toISOString() });
  showToast("Approved — nice work!");
  haptic();
  $("new").hidden = false;
  const burst = $("approve-burst");
  if (burst) {
    burst.classList.add("show");
    setTimeout(() => burst.classList.remove("show"), 900);
  }
};

$("deny").onclick = () => {
  if (!confirm("Deny this whole set?")) return;
  lockDecision();
  saveLedger({ decision:"deny", facing:state.facing, at:new Date().toISOString() });
  showToast("Denied");
  $("new").hidden = false;
};

$("build-test").onclick = () => {
  persistForm();
  streamAction("/api/build-test", {}, "Building the walk test…", "Walk test ready");
};

$("queue").onclick = () => {
  persistForm();
  const payload = {
    prompt: $("prompt").value,
    negative: $("negative").value,
    seed: +$("seed").value,
    steps: +$("steps").value,
    cfg: +$("cfg").value,
    strength: +$("style").value,
    name: $("name").value,
    ref: $("ref").value,
    pose: $("pose").value,
  };
  streamAction("/api/queue-walk", payload, "Queuing the walk folder…", "Queued");
};

["prompt","negative","style","seed","steps","cfg","name","ref","pose"].forEach(id => {
  const el = $(id);
  if (el) el.addEventListener("change", persistForm);
});

// Restore more-options open state
try {
  if (localStorage.getItem(MORE_KEY) === "1") $("more-options").open = true;
} catch (e) {}

restoreForm();
loadPicks();
checkComfy();
updateFacingReminder();
updateGenerateButtons();
updateSummary();
