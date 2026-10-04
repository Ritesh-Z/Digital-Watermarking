// Dual-axis SVG line chart for the alpha sweep.
//   left axis  : robustness score per attack (solid lines)
//   right axis : PSNR in dB (dashed white line)
const NS = "http://www.w3.org/2000/svg";
// muted, print-friendly palette that reads on light grey
export const PALETTE = ["#f4c7b8", "#e8553a", "#5b8db8", "#d88ccd", "#e3b04b", "#4fb3a9", "#9a8ac9", "#f6e7da"];

const el = (tag, attrs = {}, parent) => {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  parent?.appendChild(e);
  return e;
};

export function sweepChart(host, legendHost, tooltip, data) {
  host.innerHTML = "";
  legendHost.innerHTML = "";
  const W = host.clientWidth || 900, H = host.clientHeight || 420;
  const m = { l: 52, r: 56, t: 16, b: 40 };
  const pts = data.points;
  const ax = pts.map((p) => p.alpha);
  const x = (a) => m.l + ((a - ax[0]) / (ax.at(-1) - ax[0] || 1)) * (W - m.l - m.r);
  const lo = Math.min(0, ...pts.flatMap((p) => Object.values(p.attacks)));
  const y = (v) => m.t + (1 - (v - lo) / (1 - lo)) * (H - m.t - m.b);
  const finite = pts.map((p) => p.psnr).filter(Number.isFinite);
  const pMin = Math.floor(Math.min(...finite) / 5) * 5, pMax = Math.ceil(Math.max(...finite) / 5) * 5 || pMin + 5;
  const yp = (v) => m.t + (1 - (Math.min(v, pMax) - pMin) / (pMax - pMin || 1)) * (H - m.t - m.b);

  const svg = el("svg", { viewBox: `0 0 ${W} ${H}` }, host);
  const defs = el("defs", {}, svg);
  const glow = el("filter", { id: "glow", x: "-20%", y: "-20%", width: "140%", height: "140%" }, defs);
  el("feGaussianBlur", { stdDeviation: "1.2", result: "b" }, glow);
  const merge = el("feMerge", {}, glow);
  el("feMergeNode", { in: "b" }, merge);
  el("feMergeNode", { in: "SourceGraphic" }, merge);

  const gridG = el("g", { class: "grid" }, svg);
  const axisG = el("g", { class: "axis" }, svg);
  for (let i = 0; i <= 5; i++) {
    const v = lo + ((1 - lo) * i) / 5, yy = y(v);
    el("line", { x1: m.l, x2: W - m.r, y1: yy, y2: yy }, gridG);
    el("text", { x: m.l - 10, y: yy + 4, "text-anchor": "end" }, axisG).textContent = v.toFixed(2);
    const pv = pMin + ((pMax - pMin) * i) / 5;
    el("text", { x: W - m.r + 10, y: yp(pv) + 4 }, axisG).textContent = pv.toFixed(0);
  }
  ax.forEach((a, i) => {
    if (i % Math.ceil(ax.length / 8)) return;
    el("text", { x: x(a), y: H - m.b + 22, "text-anchor": "middle" }, axisG).textContent = +a.toPrecision(3);
  });
  el("text", { x: (W - m.r + m.l) / 2, y: H - 4, "text-anchor": "middle" }, axisG).textContent = "α (embedding strength)";
  el("text", { x: 14, y: m.t + 8 }, axisG).textContent = "score";
  el("text", { x: W - 14, y: m.t + 8, "text-anchor": "end" }, axisG).textContent = "PSNR dB";

  const path = (vals, sy) => vals.map((v, i) => `${i ? "L" : "M"}${x(ax[i]).toFixed(1)},${sy(v).toFixed(1)}`).join("");
  const series = data.attacks.map((a, i) => ({ ...a, color: PALETTE[i % PALETTE.length], vals: pts.map((p) => p.attacks[a.name]) }));
  const lines = {};
  const draw = (s) => {
    const g = el("g", { filter: "url(#glow)" }, svg);
    const p = el("path", { d: path(s.vals, y), fill: "none", stroke: s.color, "stroke-width": 2.2, "stroke-linejoin": "round" }, g);
    const len = p.getTotalLength();
    p.style.strokeDasharray = len;
    p.style.strokeDashoffset = len;
    p.getBoundingClientRect();
    p.style.transition = "stroke-dashoffset 1.4s cubic-bezier(.2,.8,.2,1)";
    p.style.strokeDashoffset = 0;
    s.vals.forEach((v, i) => el("circle", { cx: x(ax[i]), cy: y(v), r: 2.6, fill: s.color }, g));
    lines[s.name] = g;
  };
  series.forEach(draw);
  el("path", { d: path(pts.map((p) => (Number.isFinite(p.psnr) ? p.psnr : pMax)), yp), fill: "none", stroke: "#f6e7da", "stroke-width": 2, "stroke-dasharray": "6 5", opacity: 0.8 }, svg);

  // legend (click to toggle)
  const psnrBtn = document.createElement("button");
  psnrBtn.innerHTML = `<i style="background:#f6e7da"></i>PSNR (dashed)`;
  legendHost.appendChild(psnrBtn);
  for (const s of series) {
    const b = document.createElement("button");
    b.innerHTML = `<i style="background:${s.color}"></i>${s.label}`;
    b.onclick = () => { b.classList.toggle("off"); lines[s.name].style.display = b.classList.contains("off") ? "none" : ""; };
    legendHost.appendChild(b);
  }

  // crosshair
  const cross = el("line", { y1: m.t, y2: H - m.b, stroke: "rgba(244,199,184,.4)", "stroke-dasharray": "3 4", visibility: "hidden" }, svg);
  svg.addEventListener("pointermove", (ev) => {
    const r = svg.getBoundingClientRect();
    const px = ((ev.clientX - r.left) / r.width) * W;
    let best = 0;
    ax.forEach((a, i) => { if (Math.abs(x(a) - px) < Math.abs(x(ax[best]) - px)) best = i; });
    const p = pts[best];
    cross.setAttribute("x1", x(ax[best])); cross.setAttribute("x2", x(ax[best]));
    cross.setAttribute("visibility", "visible");
    tooltip.innerHTML = `α = <b>${+p.alpha.toPrecision(3)}</b> · PSNR <b>${p.psnr === null ? "∞" : p.psnr.toFixed(2)}</b> dB · SSIM <b>${p.ssim.toFixed(3)}</b><br>` +
      series.map((s) => `<span style="color:${s.color}">●</span> ${s.label}: <b>${s.vals[best].toFixed(3)}</b>`).join("<br>");
    tooltip.style.display = "block";
    tooltip.style.left = ev.clientX + "px";
    tooltip.style.top = ev.clientY + "px";
  });
  svg.addEventListener("pointerleave", () => { cross.setAttribute("visibility", "hidden"); tooltip.style.display = "none"; });
}
