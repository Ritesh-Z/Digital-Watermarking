import { createHero } from "./hero.js?v=14";
import { createBars, scoreColor } from "./bars3d.js?v=14";
import { sweepChart } from "./charts.js?v=14";

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const tooltip = $("#tooltip");

const state = {
  meta: null, scheme: "hybrid_qim", alpha: {}, size: "512", channel: "Y", band: "HH",
  cover: null, logo: null,
};

// ------------------------------------------------------------------ helpers
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toast.t);
  toast.t = setTimeout(() => t.classList.remove("show"), 5000);
}
function setStatus(kind, text) {
  const s = $("#status");
  s.className = "status " + kind;
  s.lastElementChild.textContent = text;
}
function form(extra = {}) {
  const f = new FormData();
  if (state.cover) f.append("cover", state.cover);
  if (state.logo) f.append("logo", state.logo);
  const fields = {
    scheme: state.scheme, alpha: state.alpha[state.scheme] ?? "", size: state.size,
    channel: state.channel, band: state.band, key: $("#key").value,
    redundant: $("#redundant").checked, resync: $("#resync").checked, ...extra,
  };
  for (const [k, v] of Object.entries(fields)) f.append(k, v);
  return f;
}
async function post(url, body, signal) {
  const r = await fetch(url, { method: "POST", body, signal });
  if (!r.ok) throw new Error((await r.text()).slice(0, 300) || r.statusText);
  return r.json();
}
function busy(btn, on) { btn.disabled = on; btn.classList.toggle("loading", on); }
const fmt = (v, d = 3) => (v === undefined ? "–" : v === null || !Number.isFinite(v) ? "∞" : v.toFixed(d));
const scheme = (name) => state.meta.schemes.find((s) => s.name === name);
const css = (c) => "#" + c.getHexString();

// ------------------------------------------------------------------ glossary
// Technical terms stay on the page; each one is explained here (tooltip + glossary page).
const TERMS = {
  watermark: ["Watermark", "The hidden ownership mark, here your logo, stored invisibly inside the picture."],
  cover: ["Cover image", "The original picture that the watermark is hidden in."],
  blind: ["Blind", "The logo can be read back from the watermarked image ALONE. You don't need the original picture or any saved data, only the secret key number."],
  nonblind: ["Non-blind", "To read the logo back you must have extra data saved at hiding time (the original strength values S and the logo's matrices Uw, Vw). Lose that file and the mark can't be read."],
  alpha: ["α (alpha) / strength", "How strongly the mark is written. Higher survives more damage but changes the picture more. Lower is more invisible but more fragile."],
  key: ["Secret key", "A number that decides where the bits are hidden and how they are scrambled. Without the right key the hidden bits look like random noise."],
  psnr: ["PSNR", "Peak signal-to-noise ratio, in dB: how close the watermarked image is to the original. Above about 40 dB the change can't be seen by eye."],
  ssim: ["SSIM", "Structural similarity: does the image still LOOK the same (edges, textures)? 1.000 means identical."],
  nc: ["NC", "Normalised correlation between the hidden logo and the recovered logo. 1.000 = perfect copy, 0 = no relation."],
  ber: ["BER", "Bit error rate: the share of logo bits read back wrong. 0.000 = none wrong, 0.5 = pure guessing."],
  corr: ["Correlation", "For the grey-image logos used by the SVD schemes: how similar the recovered logo is to the original (1 = same)."],
  dct: ["DCT", "Discrete cosine transform: describes a small tile of the picture as a mix of wave patterns, from smooth (low frequency) to fine detail (high frequency). JPEG uses it too."],
  dwt: ["DWT (Haar)", "Discrete wavelet transform: splits the picture into a half-size blurry version (LL) and three detail layers: horizontal (LH), vertical (HL) and diagonal (HH) edges."],
  svd: ["SVD", "Singular value decomposition: A = U·S·Vᵀ. Writes the picture as 'strength' numbers (S) and two direction matrices (U, V)."],
  qim: ["QIM", "Quantisation index modulation: round a value to a grid of steps. Landing on an even step means bit 0, an odd step means bit 1."],
  attack: ["Attack", "Anything that changes the image after watermarking (compression, noise, blur, rotation, cropping…), on purpose or by accident."],
  falsepos: ["False positive", "The detector 'finds' a watermark that was never put there. A scheme with false positives can't prove ownership, because anyone could make a fake claim."],
  decoy: ["Decoy test", "Run the owner's detector on a natural picture that was NEVER watermarked. A safe scheme should find nothing (≈ 0)."],
  claim: ["Fake claim test", "An attacker uses their own logo (\"FAKE\") and their own key on the owner's image. A safe scheme gives them nothing (≈ 0)."],
  resync: ["Re-synchronisation", "Undoing a rotation before reading the logo, by trying angles until the hidden copies agree. No original picture is needed."],
  redundancy: ["Redundancy + vote", "Every bit is hidden several times in different places, and the majority wins when reading, so damage in one area doesn't matter."],
  matlab: ["MATLAB port", "A Python translation of a scheme from your MATLAB project, giving the same algorithm and the same results."],
  paper: ["Base paper", "The method from Loke, Swami & Kulkarni (IJES 2025), which this project reproduces."],
  proposed: ["Proposed", "The improved scheme built in this project."],
};
const term = (key, label, cls = "") =>
  `<span class="chip ${cls}" data-term="${key}" title="${TERMS[key][1].replace(/"/g, "&quot;")}">${label}</span>`;
const blindChip = (blind) => (blind ? term("blind", "blind", "blind") : term("nonblind", "non-blind", "nonblind"));
const originChip = (name) => (name === "hybrid_qim" ? term("proposed", "proposed", "proposed")
  : name === "hybrid_paper" ? term("paper", "base paper", "paper") : term("matlab", "matlab port", "matlab"));

function openGlossary(focus) {
  const g = $("#glossary");
  g.hidden = false;
  document.body.style.overflow = "hidden";
  const el = focus && document.getElementById("term-" + focus);
  $$(".gl-item").forEach((x) => x.classList.toggle("hl", x === el));
  if (el) el.scrollIntoView({ block: "center" });
}
function closeGlossary() { $("#glossary").hidden = true; document.body.style.overflow = ""; }
function renderGlossary() {
  $("#gl-list").innerHTML = Object.entries(TERMS).map(([k, [t, d]]) =>
    `<div class="gl-item" id="term-${k}"><b>${t}</b><p>${d}</p></div>`).join("");
}
document.addEventListener("click", (e) => {
  const t = e.target.closest("[data-term]");
  if (t) { e.preventDefault(); e.stopPropagation(); openGlossary(t.dataset.term); }
}, true);
document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeGlossary(); });
document.addEventListener("glossary", () => openGlossary());
document.addEventListener("glossary-close", closeGlossary);
document.addEventListener("click", (e) => { if (e.target.id === "glossary") closeGlossary(); });

function countUp(el, to, digits) {
  if (to === null || !Number.isFinite(to)) { el.textContent = "∞"; return; }
  // background tabs pause requestAnimationFrame: write the final value directly
  if (document.hidden) { el.textContent = to.toFixed(digits); return; }
  const from = parseFloat(el.textContent) || 0, t0 = performance.now();
  const step = (t) => {
    const k = Math.min(1, (t - t0) / 900), e = 1 - Math.pow(1 - k, 3);
    el.textContent = (from + (to - from) * e).toFixed(digits);
    if (k < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
function gauge(id, label, value, frac, digits, note) {
  const g = $(id);
  g.querySelector("span").textContent = label;
  g.querySelector("em").textContent = note;
  countUp(g.querySelector("b"), value, digits);
  const bar = g.querySelector(".bar"), C = 2 * Math.PI * 27;
  bar.style.strokeDasharray = C;
  bar.style.strokeDashoffset = C * (1 - Math.max(0, Math.min(1, frac)));
}

// ------------------------------------------------------------------ 3-D
let hero = null, bars = null;
try { hero = createHero($("#hero-canvas")); } catch (e) { console.error(e); }
try { bars = createBars($("#bench-canvas"), tooltip); } catch (e) { console.error(e); }
// What each 3-D mode shows, in plain words (the caption card in the hero).
let heroMode = "terrain", lastRun = null;
function explain(mode) {
  const change = lastRun ? `at most ${lastRun.max_pixel_change.toFixed(0)} grey levels out of 255 (PSNR ${fmt(lastRun.psnr, 1)} dB)` : "a few grey levels out of 255";
  const E = {
    photo: ["001 / 003", "Photo: the cover image",
      "This is the cover image used in the studio below, drawn as 25,600 small points (one per block of pixels) and laid flat like a print on a table. Drag to orbit it.",
      [["real pixel colours", "linear-gradient(90deg,#5b4330,#d6a56c)"]]],
    terrain: ["002 / 003", "Terrain: brightness as height",
      "Each point is lifted by how bright it is: bright sky stands tall, dark shadows sink. This is how the algorithms 'see' an image, as a surface of numbers. DCT and wavelets describe this surface as waves of different sizes, and the watermark is hidden in those waves.",
      [["dark = low", "#3a3a3c"], ["bright = high", "#f6e7da"]]],
    energy: ["003 / 003", "Watermark energy: where the mark is hidden",
      `Points rise and glow coral where watermarking changed the pixels, strongly amplified. The real change is ${change}, invisible to the eye. An even spread means the mark is hidden everywhere, so cutting out one area can't remove it.`,
      [["unchanged", "#3a3a3c"], ["changed (amplified)", "linear-gradient(90deg,#e8553a,#f4c7b8)"]]],
  }[mode];
  $("#ex-count").textContent = E[0];
  $("#ex-title").textContent = E[1];
  $("#ex-text").textContent = E[2];
  $("#ex-legend").innerHTML = E[3].map(([l, c]) => `<span><i style="background:${c}"></i>${l}</span>`).join("");
}
$$("#hero-modes button").forEach((b) => b.addEventListener("click", () => {
  $$("#hero-modes button").forEach((x) => x.classList.toggle("on", x === b));
  heroMode = b.dataset.mode;
  hero?.setMode(heroMode);
  explain(heroMode);
}));
explain(heroMode);

// ------------------------------------------------------------------ controls
function renderSchemes() {
  const host = $("#schemes");
  host.innerHTML = "";
  for (const s of state.meta.schemes) {
    const origin = originChip(s.name);
    const b = document.createElement("button");
    b.type = "button";
    b.className = "scheme" + (s.name === state.scheme ? " on" : "");
    b.innerHTML = `<span class="t">${s.title}<span>${origin}</span></span>
      <span class="o">${blindChip(s.blind)} ${s.payload === "bits" ? "32×32 binary logo" : "grayscale logo"}</span>`;
    b.onclick = () => { state.scheme = s.name; renderSchemes(); syncAlpha(); run(); };
    host.appendChild(b);
  }
  $("#band-wrap").style.display = state.scheme === "hybrid_paper" ? "" : "none";
}
function syncAlpha() {
  const s = scheme(state.scheme), r = $("#alpha");
  r.min = s.alpha.min; r.max = s.alpha.max; r.step = s.alpha.step;
  r.value = state.alpha[s.name] ?? s.alpha.default;
  $("#alpha-val").textContent = (+r.value).toString();
}
$("#alpha").addEventListener("input", (e) => { state.alpha[state.scheme] = +e.target.value; $("#alpha-val").textContent = e.target.value; });
$("#alpha").addEventListener("change", () => run());

function seg(id, keyName) {
  $$(`#${id} button`).forEach((b) => b.addEventListener("click", () => {
    $$(`#${id} button`).forEach((x) => x.classList.toggle("on", x === b));
    state[keyName] = b.dataset.v;
    run();
  }));
}
seg("seg-size", "size"); seg("seg-channel", "channel"); seg("seg-band", "band");
$("#dice").onclick = () => { $("#key").value = Math.floor(Math.random() * 1e6); run(); };
$("#key").addEventListener("change", () => run());
$("#redundant").addEventListener("change", () => run());
$("#resync").addEventListener("change", () => run());
$("#run").onclick = () => run();

function setupDrop(id, prop) {
  const d = $(id), input = d.querySelector("input");
  const setFile = (file) => {
    state[prop] = file;
    d.querySelector("img")?.remove();
    d.classList.toggle("has", !!file);
    if (file) {
      const img = document.createElement("img");
      img.src = URL.createObjectURL(file);
      d.prepend(img);
    }
    run();
  };
  input.onchange = () => input.files[0] && setFile(input.files[0]);
  d.querySelector(".x").onclick = (e) => { e.preventDefault(); input.value = ""; setFile(null); };
  d.addEventListener("dragover", (e) => { e.preventDefault(); d.classList.add("over"); });
  d.addEventListener("dragleave", () => d.classList.remove("over"));
  d.addEventListener("drop", (e) => {
    e.preventDefault(); d.classList.remove("over");
    const f = e.dataTransfer.files[0];
    if (f && f.type.startsWith("image/")) setFile(f);
  });
}
setupDrop("#drop-cover", "cover");
setupDrop("#drop-logo", "logo");

// before/after compare slider
{
  const c = $("#compare");
  const move = (ev) => {
    const r = c.getBoundingClientRect();
    const p = Math.max(0, Math.min(100, ((ev.clientX - r.left) / r.width) * 100));
    c.style.setProperty("--split", p + "%");
  };
  c.addEventListener("pointerdown", (e) => { c.setPointerCapture(e.pointerId); move(e); c.onpointermove = move; });
  c.addEventListener("pointerup", () => { c.onpointermove = null; });
}

// ------------------------------------------------------------------ run
let ctrl = null;
async function run() {
  ctrl?.abort();
  ctrl = new AbortController();
  const btn = $("#run");
  busy(btn, true);
  $("#results").classList.add("busy");
  try {
    const r = await post("/api/run", form(), ctrl.signal);
    renderRun(r);
  } catch (e) {
    if (e.name !== "AbortError") toast("Run failed: " + e.message);
  } finally {
    if (!ctrl.signal.aborted) { busy(btn, false); $("#results").classList.remove("busy"); }
  }
}

function renderRun(r) {
  const bits = r.scheme.payload === "bits";
  gauge("#g-psnr", "PSNR", r.psnr, r.psnr === null ? 1 : (r.psnr - 20) / 30, 2, "dB · above 40 = change can't be seen");
  gauge("#g-ssim", "SSIM", r.ssim, r.ssim, 4, "1.000 = looks identical");
  if (bits) {
    gauge("#g-nc", "NC", r.clean.nc, r.clean.nc, 4, "logo match · 1.000 = perfect copy");
    gauge("#g-ber", "BER", r.clean.ber, 1 - r.clean.ber, 4, "wrong bits · 0.000 = none wrong");
  } else {
    gauge("#g-nc", "Correlation", r.clean.corr, r.clean.corr, 4, "logo similarity · 1 = same");
    gauge("#g-ber", "NC", r.clean.nc, r.clean.nc, 4, "paper's formula · 1 = perfect");
  }
  $("#img-cover").src = r.images.cover;
  $("#img-marked").src = r.images.watermarked;
  $("#img-diff").src = r.images.diff;
  $("#diff-gain").textContent = "×" + r.images.diff_gain;
  $("#img-wm").src = r.images.watermark;
  $("#img-ext").src = r.images.extracted;
  $("#wm-shape").textContent = bits ? "32×32 bits" : "grayscale";
  $$("#bands img").forEach((img, i) => { img.src = r.images.bands[i]; });
  $("#hero-psnr").textContent = fmt(r.psnr, 1);
  $("#info-line").innerHTML = [
    ["scheme", r.scheme.title], ["α", r.alpha], ["size", `${r.size}×${r.size}`],
    ["max pixel change", r.max_pixel_change.toFixed(1)], ["extraction", r.scheme.blind ? "blind" : "needs key matrices"],
    ...(r.scheme.blind ? [["copies per bit", r.copies + (r.copies < 3 ? " (use 512+ for voting/re-sync)" : "")]] : []),
    ["engine time", r.elapsed_ms + " ms"],
  ].map(([k, v]) => `<span>${k} <b>${v}</b></span>`).join("");
  hero?.setData(r.terrain);
  lastRun = r;
  explain(heroMode);
  renderAttacks(r);
}

function renderAttacks(r) {
  const rot = r.attacks.find((a) => a.name === "rotation");
  if (rot && rot.resync_angle) setFinding(3, rot.resync_angle.toFixed(2) + "°");
  const bits = r.scheme.payload === "bits";
  const host = $("#attack-grid");
  host.innerHTML = "";
  const src = { matlab: "matlab", paper: "paper", both: "both", extra: "extra" };
  for (const a of r.attacks) {
    const col = css(scoreColor(a.score));
    const card = document.createElement("div");
    card.className = "atk glass";
    card.innerHTML = `
      <div class="head"><span class="name">${a.label}</span><span class="chip ${src[a.source]}">${a.source === "both" ? "matlab + paper" : a.source}</span></div>
      <div class="imgs"><img src="${a.image}" alt="${a.label} attacked image"><img class="wm" src="${a.extracted}" alt="extracted watermark"></div>
      <div class="meter"><i style="background:${col};box-shadow:0 0 12px ${col}"></i></div>
      <div class="nums"><span>${bits ? "NC" : "corr"} <b style="color:${col}">${fmt(a.score)}</b></span>
        <span>${bits ? `BER <b>${fmt(a.ber)}</b>` : `NC <b>${fmt(a.nc)}</b>`}</span></div>
      ${a.resync_angle ? `<div class="resync">↻ re-synced: undid ${a.resync_angle.toFixed(2)}° rotation</div>` : ""}`;
    host.appendChild(card);
    requestAnimationFrame(() => requestAnimationFrame(() => {
      card.querySelector(".meter i").style.width = Math.max(2, a.score * 100) + "%";
    }));
  }
}

// ------------------------------------------------------------------ benchmark
async function runBench() {
  const btn = $("#run-bench");
  busy(btn, true);
  try {
    const r = await post("/api/benchmark", form());
    $("#bench-empty").style.display = "none";
    bars?.setData(r.rows, r.attacks);
    renderBenchTable(r);
  } catch (e) { toast("Benchmark failed: " + e.message); }
  busy(btn, false);
}
$("#run-bench").onclick = runBench;

function renderBenchTable(r) {
  const avg = (row) => (row.clean + Object.values(row.attacks).reduce((a, b) => a + b, 0)) / (1 + r.attacks.length);
  const best = r.rows.reduce((b, x) => (avg(x) > avg(b) ? x : b));
  const cell = (v) => {
    const c = scoreColor(v);
    return `<td class="sc" style="color:${css(c)};background:rgba(${c.r * 255 | 0},${c.g * 255 | 0},${c.b * 255 | 0},.08)">${fmt(v)}</td>`;
  };
  $("#bench-table").innerHTML = `
    <thead><tr><th>Scheme</th><th>α</th><th>PSNR</th><th>SSIM</th><th title="no attack">Clean</th>${r.attacks.map((a) => `<th>${a.label}</th>`).join("")}<th>Mean</th></tr></thead>
    <tbody>${r.rows.map((row) => `<tr class="${row === best ? "best" : ""}">
      <td>${row.title}${row === best ? '<span class="crown">👑</span>' : ""}</td><td class="mono">${+row.alpha.toPrecision(3)}</td>
      <td class="mono">${fmt(row.psnr, 2)}</td><td class="mono">${fmt(row.ssim)}</td>${cell(row.clean)}
      ${r.attacks.map((a) => cell(row.attacks[a.name])).join("")}${cell(avg(row))}</tr>`).join("")}</tbody>`;
}

// ------------------------------------------------------------------ sweep
async function runSweep() {
  const btn = $("#run-sweep");
  busy(btn, true);
  try {
    const r = await post("/api/sweep", form({ scheme: $("#sweep-scheme").value, points: 12 }));
    sweepChart($("#sweep-chart"), $("#sweep-legend"), tooltip, r);
  } catch (e) { toast("Sweep failed: " + e.message); }
  busy(btn, false);
}
$("#run-sweep").onclick = runSweep;

// ------------------------------------------------------------------ security
async function runSec() {
  const btn = $("#run-sec");
  busy(btn, true);
  try {
    const r = await post("/api/security", form());
    const host = $("#sec-grid");
    host.innerHTML = "";
    for (const row of r.rows) {
      const vulnerable = row.decoy > 0.5 || row.claim > 0.5;
      const cls = (v, good) => (good ? (v > 0.8 ? "ok" : "bad") : (v > 0.5 ? "bad" : "ok"));
      const card = document.createElement("div");
      card.className = "sec-card glass";
      card.innerHTML = `
        <div class="top"><div><b>${row.title}</b><br>${blindChip(row.blind)}</div>
          <span class="verdict ${vulnerable ? "bad" : "ok"}" data-term="falsepos" title="${vulnerable ? "Someone else could claim this image" : "Nobody else can claim this image"}">${vulnerable ? "⚠ FALSE POSITIVE" : "✓ SECURE"}</span></div>
        <div class="sec-tests">
          <div class="sec-test"><img src="${row.images.owner_watermark}" alt="owner watermark"><div><b class="${cls(row.genuine, true)}">${fmt(row.genuine)}</b>genuine</div></div>
          <div class="sec-test"><img src="${row.images.decoy_extract}" alt="extracted from decoy"><div><b class="${cls(row.decoy)}">${fmt(row.decoy)}</b>decoy<br>(never marked)</div></div>
          <div class="sec-test"><img src="${row.images.claim_extract}" alt="fake claim extraction"><div><b class="${cls(row.claim)}">${fmt(row.claim)}</b>fake "FAKE"<br>claim</div></div>
        </div>`;
      host.appendChild(card);
    }
    const claims = r.rows.filter((x) => !x.blind).map((x) => x.claim);
    if (claims.length) setFinding(0, Math.max(...claims).toFixed(2));
  } catch (e) { toast("Security test failed: " + e.message); }
  busy(btn, false);
}
$("#run-sec").onclick = runSec;

// ------------------------------------------------------------------ learn + findings
// [big number, what the number means, title, explanation]
const FINDINGS = [
  ["0.73", "fake-claim score (should be ≈ 0)", "SVD ownership flaw",
   "Classic SVD and the paper's own hybrid let an attacker 'extract' their own FAKE logo from the owner's image. U<sub>w</sub>, V<sub>w</sub> carry the logo, not the image, so the extraction proves nothing."],
  ["≈ 0", "score on unmarked images / wrong key", "Keyed, dithered QIM",
   "A secret key scrambles the bits and shifts the quantisation grid, so an image that was never marked, or the wrong key, reads as pure noise instead of a false match."],
  ["3 carriers", "in every 8×8 block, 9 copies per bit", "Triple-carrier embedding",
   "Each block hides the bit in its brightness (DC), a low-frequency pair and a mid-frequency pair. Noise breaks one, sharpening another, smoothing a third. The blind decoder trusts whichever survived."],
  ["2.00°", "rotation found without the original", "Blind re-sync",
   "Copies of a bit only agree when the image is straight. Trying angles and keeping the one with the most agreement undoes rotation with no reference image."],
  ["12 / 16", "unseen standard images won at equal quality", "Best on held-out images",
   "Tuned on one set of images, then tested on 8 standard images it never saw, all at the same PSNR (40 dB): best average (0.950 vs Block DCT 0.945) and most wins. Not every single image, which is honest to report (see experiment.py)."],
  ["0.91 → 1.00", "on a pure white / black graphic", "Clip-aware embedding",
   "Where pixels are already at pure white or black, the scheme picks a target it can actually reach, so no bits are lost when values would clip at 0 or 255."],
];
function renderLearn() {
  $("#learn-grid").innerHTML = state.meta.schemes.map((s, i) => `
    <div class="learn-card glass">
      <span class="lnum">${String(i + 1).padStart(2, "0")}</span>
      <h3>${s.title}</h3>
      <div class="chips">${blindChip(s.blind)} ${originChip(s.name)}</div>
      <p class="plain"><b>In plain words:</b> ${s.plain}</p>
      <ol class="steps">${s.pipeline.map((p) => `<li>${p}</li>`).join("")}</ol>
      <p class="tech">${s.description}</p>
      <div class="origin">${s.origin}</div>
    </div>`).join("");
  $("#findings-grid").innerHTML = FINDINGS.map(([stat, unit, title, text], i) => `
    <div class="finding glass" id="finding-${i}">
      <span class="n">FINDING ${String(i + 1).padStart(2, "0")}</span>
      <b class="stat">${stat}</b>
      <span class="unit">${unit}</span>
      <h3>${title}</h3>
      <p>${text}</p>
    </div>`).join("");
}
// keep the headline numbers in sync with what this page actually measured
function setFinding(i, stat) {
  const el = document.querySelector(`#finding-${i} .stat`);
  if (el) el.textContent = stat;
}


// ------------------------------------------------------------------ results / theory / journey
// Verified numbers from python/experiment.py (iso-PSNR 40 dB, 11 attacks + no attack).
const RESULTS = {
  heldout: { title: "Held-out standard images", note: "8 scikit-image test images never used for tuning (Coffee, Rocket, Moon, Grass, Text, Retina, Hubble, Immunohistochemistry) × 2 logos = 16 pairs",
    rows: [["Proposed", 0.950, "12/16", true], ["Block DCT", 0.945, "2/16"], ["Haar DWT + QIM", 0.712, "2/16"], ["Paper hybrid", 0.659, "0/16"], ["Classic SVD", 0.568, "0/16"]] },
  project: { title: "Project images", note: "Lion, your poster, grey photo, UI screenshot + 3 synthetic images × 2 logos = 14 pairs (also used during development)",
    rows: [["Proposed", 0.963, "14/14", true], ["Block DCT", 0.918, "0/14"], ["Haar DWT + QIM", 0.730, "0/14"], ["Paper hybrid", 0.652, "0/14"], ["Classic SVD", 0.446, "0/14"]] },
};
const PAPER_VS = [
  ["No attack", "≈ 0.997", "1.000"], ["Sharpening", "≈ 0.99", "≈ 1.00"], ["Lines", "≈ 0.997", "≈ 1.00"],
  ["Salt & pepper", "0.93 → 0.73", "≈ 1.00"], ["Gaussian blur", "0.04 – 0.09", "≈ 0.95–1.00"], ["Rotation", "0.55 → 0.07", "≈ 0.99"],
];
function renderResults() {
  const table = (k) => {
    const R = RESULTS[k];
    return `<div class="res-col"><h3>${R.title}</h3><p class="res-note">${R.note}</p>
      ${R.rows.map(([n, v, w, me]) => `<div class="res-row ${me ? "me" : ""}"><span class="rn">${n}</span>
        <span class="rb"><i style="width:${Math.max(2, v * 100)}%"></i></span><b>${v.toFixed(3)}</b><span class="rw">${w} wins</span></div>`).join("")}</div>`;
  };
  $("#results-grid").innerHTML = table("heldout") + table("project") + `
    <div class="res-col"><h3>vs the base paper's own numbers</h3>
      <p class="res-note">Loke et al. report NC (inflated, no mean subtraction) over their α range; ours is the stricter Pearson correlation.</p>
      <table class="mini"><tr><th>Attack</th><th>Paper reports</th><th>Proposed</th></tr>
      ${PAPER_VS.map(([a, p, o]) => `<tr><td>${a}</td><td>${p}</td><td class="good">${o}</td></tr>`).join("")}</table>
      <p class="res-note">Also: the paper's method is non-blind and can be falsely claimed (fake-claim score 0.73 vs 0.02 for ours).</p></div>`;
}

const CARRIERS = [
  ["DC brightness", "dithered QIM on each block's average"],
  ["Low-frequency pair", "QIM on D(3,2) − D(2,3)"],
  ["Mid-frequency pair", "order of D(4,3) vs D(3,4)"],
];
const SURVIVES = {       // carrier index -> attacks it survives well
  "Noise / JPEG": [1, 1, 0], "Blur / median": [1, 1, 0], "Rotation": [1, 0, 0],
  "Clipping drift": [0, 1, 1], "Sharpen / contrast": [0, 0, 1], "Lines / overlays": [0, 1, 1],
};
const PROPS = [
  ["Blind (no original needed)", "✓", "✓", "✗", "✓"],
  ["Can't be falsely claimed", "✓", "✓", "✗", "✓"],
  ["Image doesn't interfere (QIM)", "partly", "✓", "✗", "✓"],
  ["Survives scaling / contrast", "✓", "✗", "partly", "✓"],
  ["Survives clipping drift", "✓", "partly", "partly", "✓"],
  ["Diversity + weighted vote", "✗", "✗", "✗", "✓"],
];
const THEORY = [
  ["Diversity", "Like a phone using several signal paths: if one fades, the others still get through. Error probability falls sharply when independent copies are combined."],
  ["Orthogonality", "DC, D(3,2)/D(2,3) and D(4,3)/D(3,4) are orthogonal DCT basis functions, so three carriers share the same pixels without interfering (the OFDM principle)."],
  ["Reliability weighting", "Copies are combined like maximal-ratio combining: each carrier is weighted by how strongly its own copies agree, blind, with no original image."],
  ["Dirty-paper coding", "QIM (Costa 1983; Chen & Wornell 2001) lets the embedder cancel the image's own interference, unlike additive SVD."],
];
function renderTheory() {
  const atk = Object.keys(SURVIVES);
  $("#theory-grid").innerHTML = `
    <div class="th-col"><h3>Each carrier covers different attacks</h3>
      <table class="matrix"><tr><th></th>${atk.map((a) => `<th>${a}</th>`).join("")}</tr>
      ${CARRIERS.map(([n, d], i) => `<tr><td><b>${n}</b><small>${d}</small></td>${atk.map((a) => `<td class="${SURVIVES[a][i] ? "y" : "n"}">${SURVIVES[a][i] ? "●" : "·"}</td>`).join("")}</tr>`).join("")}
      <tr class="all"><td><b>All three together</b></td>${atk.map(() => `<td class="y">●</td>`).join("")}</tr></table>
      <div class="th-points">${THEORY.map(([t, d]) => `<div><b>${t}</b><p>${d}</p></div>`).join("")}</div></div>
    <div class="th-col"><h3>Properties compared</h3>
      <table class="matrix props"><tr><th></th><th>DCT</th><th>DWT</th><th>SVD / paper</th><th>Proposed</th></tr>
      ${PROPS.map(([p, ...v]) => `<tr><td>${p}</td>${v.map((x, i) => `<td class="${x === "✓" ? "y" : x === "✗" ? "n" : "m"} ${i === 3 ? "me" : ""}">${x}</td>`).join("")}</tr>`).join("")}</table>
      <div class="limit"><b>The honest limit.</b> At a fixed PSNR the change budget is split three ways, so against one attack you could
        predict (e.g. strong down-scaling of a texture), Block DCT's single, stronger carrier can win. That is why the proposed scheme is
        best on average and on most images, but not on every single one. For unknown attacks, diversity is the right design.</div></div>`;
}

const JOURNEY = [
  ["Paper hybrid did nothing", "PSNR = ∞ after embedding", "Watermark scaled to 0–1 made changes smaller than half a grey level; rounding erased them.", "Embed with the 0–255 watermark, as the paper's α range implies.", "∞ → 43 dB, works"],
  ["Anyone could claim the image", "SVD / paper: fake-claim score 0.73", "Uw, Vw carry the logo, so a forger's own matrices 'extract' their own logo (Zhang & Li 2005).", "Blind, keyed QIM with secret dither and bit scrambling.", "0.73 → 0.02"],
  ["Rotation broke every blind scheme", "2° rotation: NC ≈ 0.04", "Blocks no longer line up with where bits were written.", "Blind re-sync: try angles, keep the one where the copies agree most.", "0.04 → 0.99"],
  ["Median filter erased text", "Poster, no attack: 0.826", "An always-on 3×3 median wiped thin white strokes and shifted block brightness.", "Switching median: repair only isolated 0/255 specks, only if it helps.", "0.826 → 1.000"],
  ["Bits lost at pure black/white", "Graphic cover: 0.912", "Blocks with both 0 and 255 pixels couldn't shift brightness without clipping.", "Clip-aware water-filling: spread the change over pixels that can move.", "0.912 → 1.000"],
  ["Noise fooled the decoder", "Graphic + noise: DC copies −0.02", "Clipped noise drifts dark blocks brighter together, so DC copies agree on the wrong bit.", "Second carrier: QIM on a coefficient difference, where a drift cancels.", "→ 0.69 on that attack"],
  ["Sharpening & scaling hurt QIM", "Only tied Block DCT (6/14 wins)", "These attacks scale coefficients, moving QIM values off their grid.", "Third carrier: the scale-invariant order rule; soft, confidence-weighted vote.", "6/14 → 14/14 wins"],
  ["Was it just tuned to our images?", "Standard images: DCT mean 0.962 > 0.958", "Development images had been reused for testing (overfitting risk).", "Tune on a training set, report on held-out standard images only.", "Held-out: 0.950 vs 0.945, 12/16"],
];
function renderJourney() {
  $("#journey-grid").innerHTML = JOURNEY.map(([t, sym, cause, fix, res], i) => `
    <div class="jr">
      <span class="jn">${String(i + 1).padStart(2, "0")}</span>
      <h3>${t}</h3>
      <p class="sym">${sym}</p>
      <p><b>Why:</b> ${cause}</p>
      <p><b>Fix:</b> ${fix}</p>
      <span class="jres">${res}</span>
    </div>`).join("");
}

// ------------------------------------------------------------------ page chrome
const io = new IntersectionObserver((es) => es.forEach((e) => e.isIntersecting && e.target.classList.add("in")), { threshold: 0.08 });
$$(".reveal").forEach((s) => io.observe(s));
const navIO = new IntersectionObserver((es) => es.forEach((e) => {
  if (e.isIntersecting) $$(".nav a.link").forEach((a) => a.classList.toggle("active", a.getAttribute("href") === "#" + e.target.id));
}), { rootMargin: "-45% 0px -50% 0px" });
$$("section.block").forEach((s) => navIO.observe(s));

// ------------------------------------------------------------------ boot
(async () => {
  try {
    state.meta = await (await fetch("/api/meta")).json();
    setStatus("ok", "engine online");
  } catch (e) {
    setStatus("err", "engine offline");
    toast("Can't reach the Python engine. Start it with:  python server.py");
    return;
  }
  renderSchemes();
  syncAlpha();
  $("#sweep-scheme").innerHTML = state.meta.schemes.map((s) => `<option value="${s.name}" ${s.name === "hybrid_qim" ? "selected" : ""}>${s.title}</option>`).join("");
  renderLearn();
  renderGlossary();
  renderResults();
  renderTheory();
  renderJourney();
  // First load: fill every page for the default proposed scheme. The server
  // pre-computes these defaults at start-up, so they arrive almost instantly.
  await run();
  await runSec();
  await runBench();
  await runSweep();
})();
