// Minimal GLB viewer (no library): triangles, node transforms, base color factor/texture, orbit and pinch.
// Enough to judge a pipeline mesh on a phone. Draco/meshopt-compressed files are reported, not drawn.
import { h } from "./ui.js";

const COMP = { 5120: Int8Array, 5121: Uint8Array, 5122: Int16Array, 5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array };
const SIZE = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };
const NORM = { 5120: 127, 5121: 255, 5122: 32767, 5123: 65535 };

function parseGlb(buf) {
  const dv = new DataView(buf);
  if (dv.getUint32(0, true) !== 0x46546c67) throw new Error("not a GLB file");
  let off = 12, json = null, bin = null;
  while (off < buf.byteLength) {
    const len = dv.getUint32(off, true), type = dv.getUint32(off + 4, true);
    const chunk = buf.slice(off + 8, off + 8 + len);
    if (type === 0x4e4f534a) json = JSON.parse(new TextDecoder().decode(chunk));
    else if (type === 0x004e4942) bin = chunk;
    off += 8 + len;
  }
  if (!json) throw new Error("GLB has no JSON chunk");
  return { json, bin };
}

function readAccessor(g, bin, index) {
  const acc = g.accessors[index];
  const n = SIZE[acc.type], count = acc.count, Arr = COMP[acc.componentType];
  const out = new Float32Array(count * n);
  if (acc.bufferView === undefined) return { data: out, n, count };
  const bv = g.bufferViews[acc.bufferView];
  const base = (bv.byteOffset || 0) + (acc.byteOffset || 0);
  const stride = bv.byteStride || n * Arr.BYTES_PER_ELEMENT;
  const dv = new DataView(bin);
  const getters = { 5120: "getInt8", 5121: "getUint8", 5122: "getInt16", 5123: "getUint16", 5125: "getUint32", 5126: "getFloat32" };
  const fn = getters[acc.componentType], scale = acc.normalized ? NORM[acc.componentType] : 0;
  for (let i = 0; i < count; i++) {
    for (let k = 0; k < n; k++) {
      let v = dv[fn](base + i * stride + k * Arr.BYTES_PER_ELEMENT, true);
      if (scale) v = Math.max(v / scale, -1);
      out[i * n + k] = v;
    }
  }
  return { data: out, n, count };
}

function readIndices(g, bin, index) {
  const acc = g.accessors[index];
  const bv = g.bufferViews[acc.bufferView];
  const Arr = COMP[acc.componentType];
  const off = (bv.byteOffset || 0) + (acc.byteOffset || 0);
  return Uint32Array.from(new Arr(bin.slice(off, off + acc.count * Arr.BYTES_PER_ELEMENT)));
}

// 4x4 column-major helpers.
const ident = () => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
function mul(a, b) {
  const o = new Array(16).fill(0);
  for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) o[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k];
  return o;
}
function trs(node) {
  if (node.matrix) return node.matrix.slice();
  const [tx, ty, tz] = node.translation || [0, 0, 0];
  const [x, y, z, w] = node.rotation || [0, 0, 0, 1];
  const [sx, sy, sz] = node.scale || [1, 1, 1];
  return [
    (1 - 2 * (y * y + z * z)) * sx, (2 * (x * y + z * w)) * sx, (2 * (x * z - y * w)) * sx, 0,
    (2 * (x * y - z * w)) * sy, (1 - 2 * (x * x + z * z)) * sy, (2 * (y * z + x * w)) * sy, 0,
    (2 * (x * z + y * w)) * sz, (2 * (y * z - x * w)) * sz, (1 - 2 * (x * x + y * y)) * sz, 0,
    tx, ty, tz, 1,
  ];
}
function perspective(fovy, aspect, near, far) {
  const f = 1 / Math.tan(fovy / 2), nf = 1 / (near - far);
  return [f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, (far + near) * nf, -1, 0, 0, 2 * far * near * nf, 0];
}
function lookAt(eye, c, up) {
  let zx = eye[0] - c[0], zy = eye[1] - c[1], zz = eye[2] - c[2];
  let l = Math.hypot(zx, zy, zz); zx /= l; zy /= l; zz /= l;
  let xx = up[1] * zz - up[2] * zy, xy = up[2] * zx - up[0] * zz, xz = up[0] * zy - up[1] * zx;
  l = Math.hypot(xx, xy, xz); xx /= l; xy /= l; xz /= l;
  const yx = zy * xz - zz * xy, yy = zz * xx - zx * xz, yz = zx * xy - zy * xx;
  return [xx, yx, zx, 0, xy, yy, zy, 0, xz, yz, zz, 0,
    -(xx * eye[0] + xy * eye[1] + xz * eye[2]), -(yx * eye[0] + yy * eye[1] + yz * eye[2]), -(zx * eye[0] + zy * eye[1] + zz * eye[2]), 1];
}

async function loadImage(g, bin, texIndex) {
  const tex = g.textures && g.textures[texIndex];
  if (!tex || tex.source === undefined) return null;
  const img = g.images[tex.source];
  let blob;
  if (img.bufferView !== undefined) {
    const bv = g.bufferViews[img.bufferView];
    blob = new Blob([bin.slice(bv.byteOffset || 0, (bv.byteOffset || 0) + bv.byteLength)], { type: img.mimeType || "image/png" });
  } else if (img.uri && img.uri.startsWith("data:")) {
    blob = await (await fetch(img.uri)).blob();
  } else return null;
  return createImageBitmap(blob, { imageOrientation: "none" });
}

// Flatten the default scene into draw items with world-space positions and normals.
async function buildScene(buf) {
  const { json: g, bin } = parseGlb(buf);
  const used = (g.extensionsRequired || []).filter((e) => /draco|meshopt|quantiz/i.test(e));
  if (used.length) throw new Error("compressed GLB (" + used.join(", ") + ") is not supported by this viewer");
  const items = [];
  const scene = g.scenes ? g.scenes[g.scene || 0] : { nodes: (g.nodes || []).map((_, i) => i) };
  const walk = async (ni, parent) => {
    const node = g.nodes[ni];
    const m = mul(parent, trs(node));
    if (node.mesh !== undefined) {
      for (const prim of g.meshes[node.mesh].primitives) {
        if (prim.mode !== undefined && prim.mode !== 4) continue;
        const pos = readAccessor(g, bin, prim.attributes.POSITION);
        const nrm = prim.attributes.NORMAL !== undefined ? readAccessor(g, bin, prim.attributes.NORMAL) : null;
        const uv = prim.attributes.TEXCOORD_0 !== undefined ? readAccessor(g, bin, prim.attributes.TEXCOORD_0) : null;
        const col = prim.attributes.COLOR_0 !== undefined ? readAccessor(g, bin, prim.attributes.COLOR_0) : null;
        const idx = prim.indices !== undefined ? readIndices(g, bin, prim.indices) : Uint32Array.from({ length: pos.count }, (_, i) => i);
        const P = new Float32Array(pos.count * 3), N = new Float32Array(pos.count * 3);
        for (let i = 0; i < pos.count; i++) {
          const x = pos.data[i * 3], y = pos.data[i * 3 + 1], z = pos.data[i * 3 + 2];
          P[i * 3] = m[0] * x + m[4] * y + m[8] * z + m[12];
          P[i * 3 + 1] = m[1] * x + m[5] * y + m[9] * z + m[13];
          P[i * 3 + 2] = m[2] * x + m[6] * y + m[10] * z + m[14];
          if (nrm) {
            const a = nrm.data[i * 3], b = nrm.data[i * 3 + 1], c = nrm.data[i * 3 + 2];
            const nx = m[0] * a + m[4] * b + m[8] * c, ny = m[1] * a + m[5] * b + m[9] * c, nz = m[2] * a + m[6] * b + m[10] * c;
            const l = Math.hypot(nx, ny, nz) || 1;
            N[i * 3] = nx / l; N[i * 3 + 1] = ny / l; N[i * 3 + 2] = nz / l;
          }
        }
        if (!nrm) {
          for (let t = 0; t < idx.length; t += 3) {
            const [a, b, c] = [idx[t] * 3, idx[t + 1] * 3, idx[t + 2] * 3];
            const ux = P[b] - P[a], uy = P[b + 1] - P[a + 1], uz = P[b + 2] - P[a + 2];
            const vx = P[c] - P[a], vy = P[c + 1] - P[a + 1], vz = P[c + 2] - P[a + 2];
            const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
            for (const k of [a, b, c]) { N[k] += nx; N[k + 1] += ny; N[k + 2] += nz; }
          }
          for (let i = 0; i < N.length; i += 3) { const l = Math.hypot(N[i], N[i + 1], N[i + 2]) || 1; N[i] /= l; N[i + 1] /= l; N[i + 2] /= l; }
        }
        const mat = prim.material !== undefined && g.materials ? g.materials[prim.material] : {};
        const pbr = mat.pbrMetallicRoughness || {};
        const image = pbr.baseColorTexture ? await loadImage(g, bin, pbr.baseColorTexture.index).catch(() => null) : null;
        let C = null;
        if (col) { C = new Float32Array(pos.count * 4); for (let i = 0; i < pos.count; i++) for (let k = 0; k < 4; k++) C[i * 4 + k] = k < col.n ? col.data[i * col.n + k] : 1; }
        items.push({ P, N, UV: uv ? uv.data : null, C, idx, color: pbr.baseColorFactor || [0.8, 0.8, 0.8, 1], image });
      }
    }
    for (const c of node.children || []) await walk(c, m);
  };
  for (const ni of scene.nodes || []) await walk(ni, ident());
  if (!items.length) throw new Error("GLB has no triangle mesh");
  return { items, generator: (g.asset && g.asset.generator) || "" };
}

const VS = `attribute vec3 aP; attribute vec3 aN; attribute vec2 aUV; attribute vec4 aC;
uniform mat4 uMVP; varying vec3 vN; varying vec2 vUV; varying vec4 vC;
void main(){ vN=aN; vUV=aUV; vC=aC; gl_Position=uMVP*vec4(aP,1.0); }`;
const FS = `precision mediump float; varying vec3 vN; varying vec2 vUV; varying vec4 vC;
uniform vec4 uColor; uniform sampler2D uTex; uniform float uHasTex; uniform float uLit; uniform vec3 uLight;
void main(){ vec4 base=uColor*vC; if(uHasTex>0.5) base*=texture2D(uTex,vUV);
 vec3 n=normalize(vN); float d=max(dot(n,normalize(uLight)),0.0); float hemi=0.5+0.5*n.y;
 vec3 c = uLit>0.5 ? base.rgb*(0.35+0.25*hemi+0.6*d) : base.rgb; gl_FragColor=vec4(c,1.0); }`;

export function viewer(url) {
  const canvas = h("canvas");
  const hud = h("div", { class: "hud", text: "Loading mesh..." });
  let lit = true;
  const litBtn = h("button", { class: "chip", onclick: () => { lit = !lit; litBtn.textContent = lit ? "Lit" : "Flat"; draw(); } }, "Lit");
  const resetBtn = h("button", { class: "chip", onclick: () => { reset(); draw(); } }, "Reset");
  const wrap = h("div", { class: "viewer" }, canvas, hud, h("div", { class: "hud-r" }, litBtn, resetBtn));
  const gl = canvas.getContext("webgl", { antialias: true });
  if (!gl) { hud.textContent = "WebGL is not available in this browser."; return wrap; }
  const u32 = gl.getExtension("OES_element_index_uint");
  const sh = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return s; };
  const prog = gl.createProgram();
  gl.attachShader(prog, sh(gl.VERTEX_SHADER, VS)); gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, FS)); gl.linkProgram(prog);
  const loc = (n) => gl.getUniformLocation(prog, n);
  const A = { P: gl.getAttribLocation(prog, "aP"), N: gl.getAttribLocation(prog, "aN"), UV: gl.getAttribLocation(prog, "aUV"), C: gl.getAttribLocation(prog, "aC") };
  let draws = [], center = [0, 0, 0], radius = 1, yaw = 0.6, pitch = 0.15, dist = 3, stats = "";

  const reset = () => { yaw = 0.6; pitch = 0.15; dist = radius * 2.6; };
  function draw() {
    if (!draws.length) return;
    const w = canvas.clientWidth * devicePixelRatio | 0, hgt = canvas.clientHeight * devicePixelRatio | 0;
    if (canvas.width !== w || canvas.height !== hgt) { canvas.width = w; canvas.height = hgt; }
    gl.viewport(0, 0, w, hgt);
    gl.clearColor(0.06, 0.05, 0.075, 1); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.DEPTH_TEST);
    gl.useProgram(prog);
    const eye = [center[0] + dist * Math.cos(pitch) * Math.sin(yaw), center[1] + dist * Math.sin(pitch), center[2] + dist * Math.cos(pitch) * Math.cos(yaw)];
    const mvp = mul(perspective(0.8, w / Math.max(1, hgt), radius * 0.01, radius * 20), lookAt(eye, center, [0, 1, 0]));
    gl.uniformMatrix4fv(loc("uMVP"), false, new Float32Array(mvp));
    gl.uniform1f(loc("uLit"), lit ? 1 : 0);
    gl.uniform3f(loc("uLight"), eye[0] - center[0] + radius, eye[1] - center[1] + radius * 2, eye[2] - center[2]);
    for (const d of draws) {
      const bind = (a, buf, n) => { if (a < 0) return; if (buf) { gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.enableVertexAttribArray(a); gl.vertexAttribPointer(a, n, gl.FLOAT, false, 0, 0); } else gl.disableVertexAttribArray(a); };
      bind(A.P, d.p, 3); bind(A.N, d.n, 3); bind(A.UV, d.uv, 2); bind(A.C, d.c, 4);
      if (!d.uv && A.UV >= 0) gl.vertexAttrib2f(A.UV, 0, 0);
      if (!d.c && A.C >= 0) gl.vertexAttrib4f(A.C, 1, 1, 1, 1);
      gl.uniform4fv(loc("uColor"), d.color);
      gl.uniform1f(loc("uHasTex"), d.tex ? 1 : 0);
      if (d.tex) { gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, d.tex); gl.uniform1i(loc("uTex"), 0); }
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, d.i);
      gl.drawElements(gl.TRIANGLES, d.count, d.type, 0);
    }
    hud.textContent = stats;
  }

  // Orbit with one finger, pinch or wheel to zoom.
  const pts = new Map(); let pinch = 0;
  canvas.addEventListener("pointerdown", (e) => { canvas.setPointerCapture(e.pointerId); pts.set(e.pointerId, [e.clientX, e.clientY]); });
  canvas.addEventListener("pointermove", (e) => {
    if (!pts.has(e.pointerId)) return;
    const [px, py] = pts.get(e.pointerId); pts.set(e.pointerId, [e.clientX, e.clientY]);
    if (pts.size === 1) { yaw -= (e.clientX - px) * 0.01; pitch = Math.max(-1.5, Math.min(1.5, pitch + (e.clientY - py) * 0.01)); }
    else if (pts.size === 2) {
      const [a, b] = [...pts.values()]; const d = Math.hypot(a[0] - b[0], a[1] - b[1]);
      if (pinch) dist = Math.max(radius * 0.3, Math.min(radius * 10, dist * pinch / d)); pinch = d;
    }
    draw();
  });
  const up = (e) => { pts.delete(e.pointerId); if (pts.size < 2) pinch = 0; };
  canvas.addEventListener("pointerup", up); canvas.addEventListener("pointercancel", up);
  canvas.addEventListener("wheel", (e) => { e.preventDefault(); dist = Math.max(radius * 0.3, Math.min(radius * 10, dist * (e.deltaY > 0 ? 1.1 : 0.9))); draw(); }, { passive: false });
  canvas.addEventListener("dblclick", () => { reset(); draw(); });
  new ResizeObserver(() => draw()).observe(wrap);

  (async () => {
    try {
      const res = await fetch(url, { cache: "no-store" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const { items, generator } = await buildScene(await res.arrayBuffer());
      let min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity], verts = 0, tris = 0;
      for (const it of items) {
        for (let i = 0; i < it.P.length; i += 3) for (let k = 0; k < 3; k++) { min[k] = Math.min(min[k], it.P[i + k]); max[k] = Math.max(max[k], it.P[i + k]); }
        verts += it.P.length / 3; tris += it.idx.length / 3;
        const buf = (data, target = gl.ARRAY_BUFFER) => { const b = gl.createBuffer(); gl.bindBuffer(target, b); gl.bufferData(target, data, gl.STATIC_DRAW); return b; };
        const big = it.P.length / 3 > 65535;
        if (big && !u32) throw new Error("mesh needs 32-bit indices, which this browser lacks");
        const d = { p: buf(it.P), n: buf(it.N), uv: it.UV ? buf(it.UV) : null, c: it.C ? buf(it.C) : null, color: it.color, count: it.idx.length,
          i: buf(big ? it.idx : Uint16Array.from(it.idx), gl.ELEMENT_ARRAY_BUFFER), type: big ? gl.UNSIGNED_INT : gl.UNSIGNED_SHORT, tex: null };
        if (it.image) {
          d.tex = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, d.tex);
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, it.image);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        }
        draws.push(d);
      }
      center = [0, 1, 2].map((k) => (min[k] + max[k]) / 2);
      radius = Math.max(1e-3, Math.hypot(max[0] - min[0], max[1] - min[1], max[2] - min[2]) / 2);
      reset();
      stats = `${verts.toLocaleString()} verts - ${tris.toLocaleString()} tris - height ${(max[1] - min[1]).toFixed(3)}` + (/SIMULATED/.test(generator) ? " - SIMULATED" : "");
      wrap.dataset.loaded = "1";
      draw();
    } catch (e) {
      hud.textContent = "Could not show this mesh: " + e.message;
      wrap.dataset.error = e.message;
    }
  })();
  return wrap;
}
