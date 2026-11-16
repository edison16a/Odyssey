//
//  ScanViewerPage.swift
//  Odyssey
//
//  The web page that draws a 3D scan. It is a small WebGL2 Gaussian splat
//  renderer with a thumb stick to walk and a drag to look around. The page
//  loads "meta.json" and "model.bin" next to itself; ScanViewerView serves
//  both from the phone. It is kept as text in the app so there is nothing
//  to bundle or download.
//
//  How it stays on the floor: the scan knows the path the explorer walked
//  while filming, so the camera always takes the height of the nearest
//  point on that path, and cannot wander far away from it.
//
//  Why some views go soft: a scan only looks right from where the explorer
//  pointed the camera. Looking somewhere they never filmed shows streaks,
//  so those views are blurred and dimmed, with a note saying which way to
//  turn. Views that were filmed are drawn exactly as before.
//

import Foundation

enum ScanViewerPage {
    static let html = #"""
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<style>
  html, body { margin: 0; background: #0b0b0c; overflow: hidden; -webkit-user-select: none; user-select: none; -webkit-touch-callout: none; }
  #c { position: fixed; left: 0; top: 0; width: 100vw; height: 100vh; touch-action: none; display: block; }
  #stick { position: fixed; left: 28px; bottom: calc(40px + env(safe-area-inset-bottom)); width: 132px; height: 132px; border-radius: 50%;
           background: rgba(255,255,255,.14); border: 1.5px solid rgba(255,255,255,.45); touch-action: none; backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px); }
  #knob { position: absolute; left: 50%; top: 50%; width: 56px; height: 56px; margin: -28px 0 0 -28px; border-radius: 50%;
          background: rgba(255,255,255,.92); box-shadow: 0 4px 14px rgba(0,0,0,.35); pointer-events: none; }
  #tour { position: fixed; right: 20px; bottom: calc(64px + env(safe-area-inset-bottom)); font: 600 15px -apple-system, system-ui, sans-serif; color: #fff;
          padding: 12px 18px; border-radius: 999px; border: 1.5px solid rgba(255,255,255,.45); background: rgba(255,255,255,.14);
          backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px); touch-action: none; }
  #tour.on { background: #2b59ff; border-color: transparent; }
  .mark { position: fixed; left: 0; top: 0; padding: 5px 10px 5px 8px; border-radius: 999px; background: rgba(11,11,12,.72); color: #fff;
          font: 600 12px -apple-system, system-ui, sans-serif; white-space: nowrap; pointer-events: none; display: none;
          backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px); will-change: transform; }
  .mark::before { content: ''; display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 6px; background: #fff; vertical-align: 1px; }
  .mark.barrier::before { background: #ff5a5f; }
  .mark.helps::before { background: #34c77b; }
  #note { position: fixed; left: 50%; top: 44%; transform: translate(-50%, -50%); padding: 12px 18px; border-radius: 18px; text-align: center;
          background: rgba(11,11,12,.62); color: #fff; font: 600 15px -apple-system, system-ui, sans-serif; white-space: nowrap; pointer-events: none;
          backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); opacity: 0; transition: opacity .25s; }
  #note small { display: block; font-weight: 500; font-size: 13px; opacity: .8; margin-top: 3px; }
  #hint { position: fixed; left: 0; right: 0; bottom: calc(190px + env(safe-area-inset-bottom)); text-align: center; pointer-events: none;
          font: 500 13px -apple-system, system-ui, sans-serif; color: #fff; text-shadow: 0 1px 4px #000; opacity: .9; transition: opacity .6s; }
</style>
</head>
<body>
<canvas id="c"></canvas>
<div id="hint">Use the stick to walk. Drag anywhere to look around.</div>
<div id="note"><span id="noteTitle"></span><small id="noteHow"></small></div>
<div id="stick"><div id="knob"></div></div>
<div id="tour">Play tour</div>
<script>
const tell = (type, detail) => { try { window.webkit.messageHandlers.scan.postMessage({ type, detail: detail || '' }); } catch (e) {} };
window.onerror = (m) => tell('error', String(m));

async function load() {
  if (window.SCAN_INLINE) {
    const bin = atob(SCAN_INLINE.b64), bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return [SCAN_INLINE.meta, bytes.buffer];
  }
  // XMLHttpRequest rather than fetch: it is the one that reliably reads from an app's own address in a web view.
  const get = (url, type) => new Promise((resolve, reject) => {
    const x = new XMLHttpRequest();
    x.open('GET', url); x.responseType = type;
    x.onload = () => x.response ? resolve(x.response) : reject(new Error('Empty ' + url));
    x.onerror = () => reject(new Error('Could not load ' + url));
    x.send();
  });
  const [text, data] = await Promise.all([get('meta.json', 'text'), get('model.bin', 'arraybuffer')]);
  return [JSON.parse(text), data];
}

load().then(([META, buffer]) => start(META, buffer)).catch(e => tell('error', String(e)));

function start(META, buffer) {
const canvas = document.getElementById('c');
const gl = canvas.getContext('webgl2', { antialias: false });
if (!gl) { tell('error', 'This phone cannot draw 3D scans.'); return; }

// ---- splat data: 8 uint32 per splat = [x y z _][cov cov cov rgba] ----
const N = Math.floor(buffer.byteLength / 32);
const rows = Math.ceil(N / 1024);
const texData = new Uint32Array(2048 * rows * 4);
new Uint8Array(texData.buffer).set(new Uint8Array(buffer, 0, N * 32));
const f32 = new Float32Array(texData.buffer);

const vs = `#version 300 es
precision highp float; precision highp int;
uniform highp usampler2D u_texture;
uniform mat4 projection, view;
uniform vec2 focal, viewport;
in vec2 position; in int index;
out vec4 vColor; out vec2 vPosition;
void main () {
  uvec4 cen = texelFetch(u_texture, ivec2((uint(index) & 0x3ffu) << 1, uint(index) >> 10), 0);
  vec4 cam = view * vec4(uintBitsToFloat(cen.xyz), 1);
  vec4 pos2d = projection * cam;
  float clip = 1.2 * pos2d.w;
  if (pos2d.z < -clip || pos2d.x < -clip || pos2d.x > clip || pos2d.y < -clip || pos2d.y > clip) {
    gl_Position = vec4(0.0, 0.0, 2.0, 1.0); return;
  }
  uvec4 cov = texelFetch(u_texture, ivec2(((uint(index) & 0x3ffu) << 1) | 1u, uint(index) >> 10), 0);
  vec2 u1 = unpackHalf2x16(cov.x), u2 = unpackHalf2x16(cov.y), u3 = unpackHalf2x16(cov.z);
  mat3 Vrk = mat3(u1.x, u1.y, u2.x, u1.y, u2.y, u3.x, u2.x, u3.x, u3.y);
  mat3 J = mat3(
    focal.x / cam.z, 0., -(focal.x * cam.x) / (cam.z * cam.z),
    0., -focal.y / cam.z, (focal.y * cam.y) / (cam.z * cam.z),
    0., 0., 0.);
  mat3 T = transpose(mat3(view)) * J;
  mat3 cov2d = transpose(T) * Vrk * T;
  float mid = (cov2d[0][0] + cov2d[1][1]) / 2.0;
  float radius = length(vec2((cov2d[0][0] - cov2d[1][1]) / 2.0, cov2d[0][1]));
  float lambda1 = mid + radius, lambda2 = mid - radius;
  if (lambda2 < 0.0) { gl_Position = vec4(0.0, 0.0, 2.0, 1.0); return; }
  vec2 diag = normalize(vec2(cov2d[0][1], lambda1 - cov2d[0][0]));
  vec2 majorAxis = min(sqrt(2.0 * lambda1), 1024.0) * diag;
  vec2 minorAxis = min(sqrt(2.0 * lambda2), 1024.0) * vec2(diag.y, -diag.x);
  vColor = clamp(pos2d.z / pos2d.w + 1.0, 0.0, 1.0) *
    vec4(cov.w & 0xffu, (cov.w >> 8) & 0xffu, (cov.w >> 16) & 0xffu, (cov.w >> 24) & 0xffu) / 255.0;
  vPosition = position;
  vec2 c = vec2(pos2d) / pos2d.w;
  gl_Position = vec4(c + position.x * majorAxis / viewport + position.y * minorAxis / viewport, 0.0, 1.0);
}`;
const fs = `#version 300 es
precision highp float;
in vec4 vColor; in vec2 vPosition;
out vec4 fragColor;
void main () {
  float A = -dot(vPosition, vPosition);
  if (A < -4.0) discard;
  float B = exp(A) * vColor.a;
  fragColor = vec4(B * vColor.rgb, B);
}`;
function shader(type, src) {
  const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) tell('error', gl.getShaderInfoLog(s));
  return s;
}
const prog = gl.createProgram();
gl.attachShader(prog, shader(gl.VERTEX_SHADER, vs));
gl.attachShader(prog, shader(gl.FRAGMENT_SHADER, fs));
gl.linkProgram(prog); gl.useProgram(prog);

gl.disable(gl.DEPTH_TEST);
gl.enable(gl.BLEND);
gl.blendFuncSeparate(gl.ONE_MINUS_DST_ALPHA, gl.ONE, gl.ONE_MINUS_DST_ALPHA, gl.ONE);
gl.blendEquationSeparate(gl.FUNC_ADD, gl.FUNC_ADD);

const quad = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, quad);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-2, -2, 2, -2, 2, 2, -2, 2]), gl.STATIC_DRAW);
const aPos = gl.getAttribLocation(prog, 'position');
gl.enableVertexAttribArray(aPos);
gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);

const tex = gl.createTexture();
gl.bindTexture(gl.TEXTURE_2D, tex);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32UI, 2048, rows, 0, gl.RGBA_INTEGER, gl.UNSIGNED_INT, texData);
gl.uniform1i(gl.getUniformLocation(prog, 'u_texture'), 0);

const order = new Uint32Array(N);
const indexBuf = gl.createBuffer();
const aIdx = gl.getAttribLocation(prog, 'index');
gl.enableVertexAttribArray(aIdx);
gl.bindBuffer(gl.ARRAY_BUFFER, indexBuf);
gl.vertexAttribIPointer(aIdx, 1, gl.INT, 0, 0);
gl.vertexAttribDivisor(aIdx, 1);

const uProj = gl.getUniformLocation(prog, 'projection'), uView = gl.getUniformLocation(prog, 'view');
const uFocal = gl.getUniformLocation(prog, 'focal'), uViewport = gl.getUniformLocation(prog, 'viewport');

// ---- camera: x right, y down, z forward ----
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = a => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
const up = norm(META.up), down = up.map(v => -v);
const path = META.path;
const flat = v => { const h = dot(v, up); return norm([v[0] - h * up[0], v[1] - h * up[1], v[2] - h * up[2]]); };
const f0 = flat(path[0].slice(4, 7)), r0 = cross(down, f0);
const angles = fw => { fw = norm(fw); return [Math.atan2(dot(fw, r0), dot(fw, f0)), Math.asin(Math.max(-1, Math.min(1, dot(fw, up))))]; };
let prevYaw = 0;
const pts = path.map(p => {
  let [yaw, pitch] = angles(p.slice(4, 7));
  while (yaw - prevYaw > Math.PI) yaw -= 2 * Math.PI;
  while (yaw - prevYaw < -Math.PI) yaw += 2 * Math.PI;
  prevYaw = yaw;
  const pos = p.slice(1, 4);
  return { t: p[0], pos, yaw, pitch, h: dot(pos, up), fw: flat(p.slice(4, 7)) };
});

// ---- features found in the video, as labels floating in the space ----
// A feature is known by the frame it shows best in, so it sits a little ahead of where the camera
// was at that moment. That is a rough spot, good for "the stairs are over there", not a measurement.
const taken = {};
const marks = (META.features || []).map(f => {
  let at = pts[0];
  for (const p of pts) if (Math.abs(p.t - f.frame) < Math.abs(at.t - f.frame)) at = p;
  if (Math.abs(at.t - f.frame) > 40) return null; // that part of the walk is not in this scan
  const stack = taken[at.t] = (taken[at.t] || 0) + 1;
  const el = document.createElement('div');
  el.className = 'mark ' + (f.tone || 'neutral');
  el.textContent = f.label;
  document.body.appendChild(el);
  return { el, pos: at.pos.map((v, i) => v + at.fw[i] * 1.8 + up[i] * 0.22 * (stack - 1)) };
}).filter(Boolean);
function placeMarks(right, dn, fwd, focal) {
  const shown = [];
  for (const m of marks) {
    const d = [m.pos[0] - cam.pos[0], m.pos[1] - cam.pos[1], m.pos[2] - cam.pos[2]];
    const z = dot(d, fwd), far = Math.hypot(d[0], d[1], d[2]);
    m.el.style.display = 'none';
    if (z < 0.5 || far > 8) continue;
    shown.push({ m, far, x: (canvas.width / 2 + focal * dot(d, right) / z) / quality, y: (canvas.height / 2 + focal * dot(d, dn) / z) / quality });
  }
  // The nearest few, and none on top of another: a label that would cover one already placed moves up.
  shown.sort((a, b) => a.far - b.far);
  const boxes = [];
  for (const s of shown.slice(0, 6)) {
    const w = (s.m.w = s.m.w || s.m.el.offsetWidth || 120), h = 28;
    s.m.el.style.display = 'block';
    if (!s.m.w) s.m.w = s.m.el.offsetWidth;
    let y = s.y;
    for (let tries = 0; tries < 8 && boxes.some(b => Math.abs(b.x - s.x) < (b.w + w) / 2 && Math.abs(b.y - y) < h); tries++) y -= h;
    boxes.push({ x: s.x, y, w });
    s.m.el.style.opacity = Math.min(1, (8 - s.far) / 3) * (1 - soft);
    s.m.el.style.transform = `translate(${s.x}px, ${y}px) translate(-50%, -100%)`;
  }
}

const cam = { pos: pts[0].pos.slice(), yaw: pts[0].yaw, pitch: 0 };
let touring = false, tourT = pts[0].t, dirty = true;
function tourPose(t) {
  let i = 0;
  while (i < pts.length - 2 && pts[i + 1].t < t) i++;
  const a = pts[i], b = pts[i + 1];
  const k = Math.max(0, Math.min(1, (t - a.t) / ((b.t - a.t) || 1)));
  cam.pos = a.pos.map((v, j) => v + (b.pos[j] - v) * k);
  cam.yaw = a.yaw + (b.yaw - a.yaw) * k;
  cam.pitch = (a.pitch + (b.pitch - a.pitch) * k) * 0.6;
}
function basis() {
  const f = [0, 1, 2].map(i => Math.cos(cam.yaw) * f0[i] + Math.sin(cam.yaw) * r0[i]);
  const right = cross(down, f);
  const fwd = [0, 1, 2].map(i => Math.cos(cam.pitch) * f[i] + Math.sin(cam.pitch) * up[i]);
  return { f, right, fwd, dn: cross(fwd, right) };
}
/// The nearest point of the walked path, measured along the floor.
function nearest(pos) {
  let best = 0, bestD = Infinity;
  for (let i = 0; i < pts.length; i++) {
    const d = [pos[0] - pts[i].pos[0], pos[1] - pts[i].pos[1], pos[2] - pts[i].pos[2]];
    const v = dot(d, up), flat2 = dot(d, d) - v * v;
    if (flat2 < bestD) { bestD = flat2; best = i; }
  }
  return { point: pts[best], dist: Math.sqrt(Math.max(0, bestD)) };
}

// ---- only what was filmed ----
// How close a view is to one the explorer filmed: 1 is filmed, 0 was never seen. A view holds up when a
// point of the walk right here looked the same way. Points further off only count for less, so a part of
// the walk that passed nearby facing another way does not vouch for this one. Stepping off the path is
// fine for a couple of metres, then the whole view fades out as the edge of what was filmed.
// The distances and angles were set by eye against real scans.
const ease = (a, b, v) => { const t = Math.max(0, Math.min(1, (v - a) / (b - a))); return t * t * (3 - 2 * t); };
const away = new Float32Array(pts.length);
function cover(pos, f) {
  let near = Infinity;
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i].pos, x = pos[0] - p[0], y = pos[1] - p[1], z = pos[2] - p[2], v = x * up[0] + y * up[1] + z * up[2];
    away[i] = Math.sqrt(Math.max(0, x * x + y * y + z * z - v * v));
    if (away[i] < near) near = away[i];
  }
  let best = 0;
  for (let i = 0; i < pts.length; i++) {
    const close = 1 - ease(0.3, 1.3, away[i] - near);
    if (close <= best) continue;
    const same = 1 - ease(0.25, 1.3, Math.acos(Math.max(-1, Math.min(1, dot(f, pts[i].fw)))));
    if (close * same > best) best = close * same;
  }
  return best * (1 - ease(1.5, 3.0, near));
}
const flatAt = yaw => [0, 1, 2].map(i => Math.cos(yaw) * f0[i] + Math.sin(yaw) * r0[i]);
const noteEl = document.getElementById('note'), noteTitle = document.getElementById('noteTitle'), noteHow = document.getElementById('noteHow');
let soft = 0, softShown = -1;
/// Blur and dim the picture by how little of this view was filmed, and say which way to turn.
function soften(f) {
  soft = 1 - ease(0.25, 0.75, cover(cam.pos, f));
  const k = Math.round(soft * 40) / 40;
  if (k !== softShown) {
    softShown = k;
    canvas.style.filter = k ? `blur(${(20 * k).toFixed(1)}px) brightness(${(1 - 0.42 * k).toFixed(2)}) saturate(${(1 - 0.35 * k).toFixed(2)})` : '';
    canvas.style.transform = k ? `scale(${(1 + 0.12 * k).toFixed(3)})` : '';   // keeps the blurred edges off the screen
  }
  if (soft < 0.6) { noteEl.style.opacity = 0; return; }
  // The nearest direction that was filmed from here, if there is one.
  let turn = 0;
  for (let a = 0.1; a <= Math.PI && !turn; a += 0.1) {
    if (cover(cam.pos, flatAt(cam.yaw - a)) > 0.8) turn = -1;
    else if (cover(cam.pos, flatAt(cam.yaw + a)) > 0.8) turn = 1;
  }
  noteTitle.textContent = turn ? 'This side was not filmed' : 'This spot was not filmed';
  noteHow.textContent = turn < 0 ? '‹ Turn left to keep exploring' : turn > 0 ? 'Turn right › to keep exploring' : 'Walk back to keep exploring';
  noteEl.style.opacity = 1;
}

// ---- depth sort, nearest first ----
const depths = new Float32Array(N), keys = new Uint16Array(N), counts = new Uint32Array(65536);
let sortedFwd = [0, 0, 0], sortedPos = [1e9, 0, 0];
function sortSplats(fwd, pos) {
  const moved = Math.hypot(pos[0] - sortedPos[0], pos[1] - sortedPos[1], pos[2] - sortedPos[2]);
  if (dot(fwd, sortedFwd) > 0.9995 && moved < 0.12) return;
  sortedFwd = fwd.slice(); sortedPos = pos.slice();
  let lo = Infinity, hi = -Infinity;
  for (let i = 0; i < N; i++) {
    const d = fwd[0] * f32[8 * i] + fwd[1] * f32[8 * i + 1] + fwd[2] * f32[8 * i + 2];
    depths[i] = d; if (d < lo) lo = d; if (d > hi) hi = d;
  }
  const inv = 65535 / ((hi - lo) || 1);
  counts.fill(0);
  for (let i = 0; i < N; i++) { const k = ((depths[i] - lo) * inv) | 0; keys[i] = k; counts[k]++; }
  let sum = 0;
  for (let k = 0; k < 65536; k++) { const c = counts[k]; counts[k] = sum; sum += c; }
  for (let i = 0; i < N; i++) order[counts[keys[i]]++] = i;
  gl.bindBuffer(gl.ARRAY_BUFFER, indexBuf);
  gl.bufferData(gl.ARRAY_BUFFER, order, gl.DYNAMIC_DRAW);
}

let quality = Math.min(window.devicePixelRatio || 1, 1.5);
function resize() {
  const w = Math.round(canvas.clientWidth * quality), h = Math.round(canvas.clientHeight * quality);
  if (w > 0 && h > 0 && (canvas.width !== w || canvas.height !== h)) { canvas.width = w; canvas.height = h; dirty = true; }
}
function draw() {
  const { f, right, fwd, dn } = basis();
  const p = cam.pos, w = canvas.width, h = canvas.height;
  const focal = Math.min(w, h) / 2 / Math.tan(33 * Math.PI / 180);
  const znear = 0.1, zfar = 300;
  gl.viewport(0, 0, w, h);
  gl.uniformMatrix4fv(uProj, false, [2 * focal / w, 0, 0, 0, 0, -2 * focal / h, 0, 0, 0, 0, zfar / (zfar - znear), 1, 0, 0, -(zfar * znear) / (zfar - znear), 0]);
  gl.uniformMatrix4fv(uView, false, [right[0], dn[0], fwd[0], 0, right[1], dn[1], fwd[1], 0, right[2], dn[2], fwd[2], 0, -dot(right, p), -dot(dn, p), -dot(fwd, p), 1]);
  gl.uniform2f(uFocal, focal, focal);
  gl.uniform2f(uViewport, w, h);
  sortSplats(fwd, p);
  soften(f);
  placeMarks(right, dn, fwd, focal);
  gl.clearColor(0, 0, 0, 0);
  gl.clear(gl.COLOR_BUFFER_BIT);
  gl.drawArraysInstanced(gl.TRIANGLE_FAN, 0, 4, N);
}

// ---- controls ----
const stickEl = document.getElementById('stick'), knob = document.getElementById('knob');
const tourEl = document.getElementById('tour'), hint = document.getElementById('hint');
const stick = { x: 0, y: 0, id: null };
const keys2 = new Set();
function setTour(on) { touring = on; tourEl.textContent = on ? 'Stop tour' : 'Play tour'; tourEl.classList.toggle('on', on); if (on) hint.style.opacity = 0; }
function used() { setTour(false); hint.style.opacity = 0; }
tourEl.addEventListener('pointerdown', e => { e.preventDefault(); setTour(!touring); });

function stickMove(e) {
  const r = stickEl.getBoundingClientRect(), half = r.width / 2;
  let x = (e.clientX - r.left - half) / half, y = (e.clientY - r.top - half) / half;
  const len = Math.hypot(x, y);
  if (len > 1) { x /= len; y /= len; }
  stick.x = x; stick.y = y;
  knob.style.transform = `translate(${x * half * 0.62}px, ${y * half * 0.62}px)`;
}
stickEl.addEventListener('pointerdown', e => { e.preventDefault(); stickEl.setPointerCapture(e.pointerId); stick.id = e.pointerId; used(); stickMove(e); });
stickEl.addEventListener('pointermove', e => { if (e.pointerId === stick.id) stickMove(e); });
for (const ev of ['pointerup', 'pointercancel']) stickEl.addEventListener(ev, e => {
  if (e.pointerId !== stick.id) return;
  stick.id = null; stick.x = 0; stick.y = 0; knob.style.transform = '';
});

let look = null;
canvas.addEventListener('pointerdown', e => { if (look) return; canvas.setPointerCapture(e.pointerId); look = { id: e.pointerId, x: e.clientX, y: e.clientY }; used(); });
canvas.addEventListener('pointermove', e => {
  if (!look || e.pointerId !== look.id) return;
  cam.yaw += (e.clientX - look.x) * 0.005;
  cam.pitch = Math.max(-1.2, Math.min(1.2, cam.pitch - (e.clientY - look.y) * 0.005));
  look.x = e.clientX; look.y = e.clientY; dirty = true;
});
for (const ev of ['pointerup', 'pointercancel']) canvas.addEventListener(ev, e => { if (look && e.pointerId === look.id) look = null; });

const keymap = { w: 'f', arrowup: 'f', s: 'b', arrowdown: 'b', a: 'l', d: 'r', arrowleft: 'tl', arrowright: 'tr' };
window.addEventListener('keydown', e => { const k = keymap[e.key.toLowerCase()]; if (k) { keys2.add(k); used(); e.preventDefault(); } });
window.addEventListener('keyup', e => { const k = keymap[e.key.toLowerCase()]; if (k) keys2.delete(k); });

const REACH = 2.5;    // metres you may stray from the walked path; further out the scan falls apart
const SPEED = 1.5;    // metres per second at full stick
let last = performance.now(), slow = 0;
function tick(now) {
  const dt = Math.min(0.1, (now - last) / 1000); last = now;
  resize();
  if (touring) {
    tourT += dt * 6 * 1.1;
    if (tourT > pts[pts.length - 1].t) tourT = pts[0].t;
    tourPose(tourT); dirty = true;
  } else {
    let fwdAmt = -stick.y + (keys2.has('f') ? 1 : 0) - (keys2.has('b') ? 1 : 0);
    let sideAmt = stick.x + (keys2.has('r') ? 1 : 0) - (keys2.has('l') ? 1 : 0);
    if (keys2.has('tl')) { cam.yaw -= 1.4 * dt; dirty = true; }
    if (keys2.has('tr')) { cam.yaw += 1.4 * dt; dirty = true; }
    if (fwdAmt || sideAmt) {
      const { f, right } = basis(), before = cam.pos.slice();
      for (let i = 0; i < 3; i++) cam.pos[i] += (f[i] * fwdAmt + right[i] * sideAmt) * SPEED * dt;
      const was = nearest(before), now2 = nearest(cam.pos);
      // Past the edge of what was filmed: only moves that come back are allowed.
      if (now2.dist > REACH && now2.dist > was.dist) cam.pos = before;
      dirty = true;
    }
    // Keep eye height above the floor wherever the floor is here.
    const want = nearest(cam.pos).point.h, have = dot(cam.pos, up), fix = (want - have) * Math.min(1, dt * 5);
    if (Math.abs(want - have) > 0.002) { for (let i = 0; i < 3; i++) cam.pos[i] += up[i] * fix; dirty = true; }
  }
  if (dirty) {
    const t0 = performance.now();
    draw(); gl.finish(); dirty = false;
    // A phone that cannot keep up gets a softer picture instead of a stutter.
    slow = performance.now() - t0 > 40 ? slow + 1 : 0;
    if (slow > 12 && quality > 0.8) { quality *= 0.8; slow = 0; }
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
tell('ready', String(N));
}
</script>
</body>
</html>
"""#
}
