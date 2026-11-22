import { app } from "../../scripts/app.js";
import { api } from "../../scripts/api.js";

function titled(title) {
    return (app.graph?.nodes || []).find((node) => node.title === title);
}

function widget(node, name) {
    const found = node?.widgets?.find((item) => item.name === name);
    return found ? found.value : "";
}

function setWidget(node, name, value) {
    const found = node?.widgets?.find((item) => item.name === name);
    if (!found) {
        return false;
    }
    found.value = value;
    if (found.callback) {
        found.callback(value);
    }
    return true;
}

function modelKind() {
    return titled("Style lock") ? "sdxl" : "klein";
}

async function send(decision, host) {
    const keep = titled("3. What to keep");
    const avoid = titled("3. What to avoid");
    const strength = titled("Style strength");
    const steps = titled("Steps");
    const guidance = titled("Guidance");
    const seed = titled("Seed");
    const sampler = titled("Sampler knobs");
    const finish = titled("4. Finish");
    const her = titled("1. Her picture");
    const pose = titled("2. Pose depth");
    const picture = titled("Picture to restyle");
    const payload = {
        decision,
        note: widget(host, "note"),
        character: widget(host, "character") || "female",
        ledger: widget(host, "ledger"),
        prompt: widget(keep, "text"),
        negative: widget(avoid, "text"),
        strength: widget(strength, "strength_model") || widget(strength, "weight"),
        steps: widget(steps, "steps") || widget(sampler, "steps"),
        cfg: widget(guidance, "cfg") || widget(sampler, "cfg"),
        seed: widget(seed, "noise_seed") || widget(sampler, "seed"),
        denoise: widget(sampler, "denoise"),
        look: widget(finish, "look"),
        ref: [widget(titled("Style lock"), "which"), widget(her, "which"), widget(picture, "image")].filter(Boolean).join(" | "),
        pose: widget(pose, "image"),
    };
    const response = await api.fetchApi("/wdb/review", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });
    const body = await response.json();
    if (!body.ok) {
        window.alert(body.error || "Could not save the review.");
        return;
    }
    const word = decision === "yes" ? "Approved" : "Denied";
    window.alert(word + " " + body.id + ".\nThe book has this picture. The model did not run again.");
}

async function showBook(host) {
    const ledger = encodeURIComponent(widget(host, "ledger") || "");
    const response = await api.fetchApi("/wdb/status?ledger=" + ledger);
    const body = await response.json();
    window.alert(body.ok ? body.text : (body.error || "Could not read the book."));
}

async function useWords(host) {
    const facing = encodeURIComponent(widget(host, "facing") || "down");
    const job = encodeURIComponent(widget(host, "job") || "pose still");
    const response = await api.fetchApi(
        "/wdb/words?facing=" + facing + "&job=" + job + "&model=" + modelKind()
    );
    const body = await response.json();
    if (!body.ok) {
        window.alert(body.error || "Could not build the words.");
        return;
    }
    const keep = titled("3. What to keep");
    if (!setWidget(keep, "text", body.text)) {
        window.alert("The What to keep box is not on this graph.");
        return;
    }
    window.alert("What to keep now matches this facing. Edit the box if you want, then Queue Prompt.");
}

const WALK_FACINGS = [
    ["up_left", "Up left"],
    ["up", "Up"],
    ["up_right", "Up right"],
    ["left", "Left"],
    ["right", "Right"],
    ["down_left", "Down left"],
    ["down", "Down"],
    ["down_right", "Down right"],
];

function walkFacing() {
    const which = widget(titled("1. Her picture"), "which");
    return WALK_FACINGS.some(([key]) => key === which) ? which : "down";
}

function ledgerQuery() {
    const host = titled("5. Approve or deny") || titled("Walk frames");
    const ledger = widget(host, "ledger");
    return ledger ? "&ledger=" + encodeURIComponent(ledger) : "";
}

function frameUrl(facing, name) {
    const route = "/wdb/walk-frame?character=female&facing=" + encodeURIComponent(facing) +
        "&name=" + encodeURIComponent(name) + ledgerQuery();
    return typeof api.apiURL === "function" ? api.apiURL(route) : route;
}

async function buildWalk(facing) {
    const host = titled("Walk frames") || titled("5. Approve or deny");
    const response = await api.fetchApi("/wdb/walk-build", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            facing,
            character: "female",
            ledger: widget(host, "ledger"),
        }),
    });
    const body = await response.json();
    if (!body.ok) {
        window.alert(body.error || "Could not build the walk test.");
        return;
    }
    window.alert(
        body.text + ".\nSet Her picture to " + facing.replaceAll("_", " ") +
        ", then Queue the walk folder.\nThe model has not run yet."
    );
}

function openReel() {
    const old = document.getElementById("wdb-walk-reel");
    if (old) {
        old.remove();
    }
    const panel = document.createElement("div");
    panel.id = "wdb-walk-reel";
    panel.style.cssText = "position:fixed;inset:24px;z-index:50;background:#1c1c1c;color:#f2f2f2;border:1px solid #666;border-radius:8px;display:flex;flex-direction:column;font:14px sans-serif;";
    const bar = document.createElement("div");
    bar.style.cssText = "display:flex;gap:8px;align-items:center;padding:10px;border-bottom:1px solid #444;";
    const title = document.createElement("strong");
    title.textContent = "Walk clips";
    const pick = document.createElement("select");
    for (const [key, label] of WALK_FACINGS) {
        const option = document.createElement("option");
        option.value = key;
        option.textContent = label;
        pick.appendChild(option);
    }
    pick.value = walkFacing();
    const counts = document.createElement("span");
    counts.style.marginLeft = "8px";
    const filter = document.createElement("select");
    for (const [key, label] of [["all", "All frames"], ["good", "Good"], ["bad", "Bad"], ["", "Unmarked"]]) {
        const option = document.createElement("option");
        option.value = key;
        option.textContent = label;
        filter.appendChild(option);
    }
    const build = document.createElement("button");
    build.textContent = "Build the walk test";
    const close = document.createElement("button");
    close.textContent = "Close";
    close.style.marginLeft = "auto";
    bar.append(title, pick, filter, counts, build, close);
    const grid = document.createElement("div");
    grid.style.cssText = "overflow:auto;padding:10px;display:flex;flex-wrap:wrap;gap:8px;align-content:flex-start;";
    panel.append(bar, grid);
    document.body.appendChild(panel);
    close.onclick = () => panel.remove();
    build.onclick = () => buildWalk(pick.value);
    const draw = () => loadReel(pick.value, filter.value, grid, counts);
    pick.onchange = draw;
    filter.onchange = draw;
    draw();
}

function paintCard(card, frame) {
    card.style.borderColor = frame.mark === "good" ? "#3c6" : frame.mark === "bad" ? "#c44" : "#333";
}

async function loadReel(facing, show, grid, counts) {
    grid.textContent = "Loading frames...";
    const response = await api.fetchApi(
        "/wdb/walk-reel?character=female&facing=" + encodeURIComponent(facing) + ledgerQuery()
    );
    const body = await response.json();
    grid.textContent = "";
    if (!body.ok) {
        grid.textContent = body.error || "Could not load the walk clips.";
        return;
    }
    const frames = body.frames || [];
    const recount = () => {
        const good = frames.filter((frame) => frame.mark === "good").length;
        const bad = frames.filter((frame) => frame.mark === "bad").length;
        counts.textContent = good + " good, " + bad + " bad, " + (frames.length - good - bad) + " unmarked";
    };
    recount();
    const visible = frames.filter((frame) => show === "all" || frame.mark === show);
    for (const frame of visible) {
        grid.appendChild(reelCard(facing, frame, (card) => {
            paintCard(card, frame);
            if (show !== "all" && frame.mark !== show) {
                card.remove();
            }
            recount();
            if (!grid.children.length) {
                grid.textContent = "Nothing in this filter.";
            }
        }));
    }
    if (!visible.length) {
        grid.textContent = frames.length ? "Nothing in this filter." : "This facing has no frames.";
    }
}

function reelCard(facing, frame, onMark) {
    const card = document.createElement("div");
    card.style.cssText = "width:112px;background:#111;border:2px solid #333;border-radius:6px;padding:4px;";
    paintCard(card, frame);
    const img = document.createElement("img");
    img.alt = frame.name;
    img.loading = "lazy";
    img.style.cssText = "width:104px;height:140px;object-fit:contain;background:#000;display:block;";
    img.src = frameUrl(facing, frame.name);
    const name = document.createElement("div");
    name.textContent = frame.name;
    name.style.cssText = "text-align:center;font-size:11px;margin-top:2px;";
    const row = document.createElement("div");
    row.style.cssText = "display:flex;gap:4px;margin-top:4px;";
    for (const [mark, label] of [["good", "Good"], ["bad", "Bad"]]) {
        const button = document.createElement("button");
        button.textContent = label;
        button.style.flex = "1";
        button.onclick = async () => {
            const next = frame.mark === mark ? "" : mark;
            const response = await api.fetchApi("/wdb/walk-pick", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    character: "female",
                    facing,
                    name: frame.name,
                    mark: next,
                    ledger: widget(titled("5. Approve or deny"), "ledger"),
                }),
            });
            const body = await response.json();
            if (!body.ok) {
                window.alert(body.error || "Could not save the mark.");
                return;
            }
            frame.mark = next;
            onMark(card);
        };
        row.appendChild(button);
    }
    card.append(img, name, row);
    return card;
}

async function queueWalk(host) {
    const her = titled("1. Her picture");
    const keep = titled("3. What to keep");
    const avoid = titled("3. What to avoid");
    const strength = titled("Style strength");
    const steps = titled("Steps");
    const guidance = titled("Guidance");
    const seed = titled("Seed");
    const finish = titled("4. Finish");
    const response = await api.fetchApi("/wdb/walk", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            folder: widget(host, "folder") || "wdb-walk",
            which: widget(her, "which") || "down",
            prompt: widget(keep, "text"),
            negative: widget(avoid, "text"),
            strength: widget(strength, "strength_model") || 1,
            steps: widget(steps, "steps") || 28,
            cfg: widget(guidance, "cfg") || 4,
            seed: widget(seed, "noise_seed") || 7,
            look: widget(finish, "look") || "model output",
        }),
    });
    const body = await response.json();
    if (!body.ok) {
        window.alert(body.error || "Could not queue the walk.");
        return;
    }
    window.alert(
        "Queued " + body.queued + " walk frames.\n" +
        "Each one takes a few minutes. They land in the output folder wdb/walk.\n" +
        "This did not Approve them."
    );
}

async function saveGraph(host) {
    const kind = app.graph?.extra?.wdb;
    const name = (kind === "style" || titled("Style lock"))
        ? "WDB Style lock.json"
        : "WDB Character.json";
    const response = await api.fetchApi("/wdb/save-workflow", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            name,
            ledger: widget(host, "ledger"),
            graph: app.graph.serialize(),
        }),
    });
    const body = await response.json();
    if (!body.ok) {
        window.alert(body.error || "Could not save the graph.");
        return;
    }
    window.alert("Saved " + body.name + " into the game repo.\nCommit that file when you want these knobs kept.");
}

function addButton(node, label, action) {
    const button = node.addWidget("button", label, null, action);
    button.serialize = false;
}

app.registerExtension({
    name: "wdb.character.review",
    async beforeRegisterNodeDef(nodeType, nodeData) {
        const original = nodeType.prototype.onNodeCreated;
        if (nodeData.name === "WDBApprove") {
            nodeType.prototype.onNodeCreated = function () {
                const result = original?.apply(this, arguments);
                addButton(this, "Approve", () => send("yes", this));
                addButton(this, "Deny", () => send("no", this));
                addButton(this, "Show the book", () => showBook(this));
                addButton(this, "Save knobs into the repo", () => saveGraph(this));
                return result;
            };
        } else if (nodeData.name === "WDBWords") {
            nodeType.prototype.onNodeCreated = function () {
                const result = original?.apply(this, arguments);
                addButton(this, "Use these words", () => useWords(this));
                return result;
            };
        } else if (nodeData.name === "WDBWalk") {
            nodeType.prototype.onNodeCreated = function () {
                const result = original?.apply(this, arguments);
                addButton(this, "Review the walk clips", () => openReel());
                addButton(this, "Build the walk test", () => buildWalk(walkFacing()));
                addButton(this, "Queue the walk folder", () => queueWalk(this));
                return result;
            };
        }
    },
});
