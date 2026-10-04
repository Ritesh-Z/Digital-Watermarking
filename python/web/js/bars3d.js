// 3-D benchmark: one bar per (scheme, attack); height = robustness score.
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { CSS2DRenderer, CSS2DObject } from "three/addons/renderers/CSS2DRenderer.js";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";

const STOPS = [[0, "#e8553a"], [0.5, "#e3b04b"], [0.85, "#f4c7b8"], [1, "#5b8db8"]];   // coral -> mustard -> peach -> steel blue
export function scoreColor(v) {
  v = Math.max(0, Math.min(1, v));
  for (let i = 1; i < STOPS.length; i++) {
    if (v <= STOPS[i][0]) {
      const [a, ca] = STOPS[i - 1], [b, cb] = STOPS[i];
      return new THREE.Color(ca).lerp(new THREE.Color(cb), (v - a) / (b - a));
    }
  }
  return new THREE.Color(STOPS.at(-1)[1]);
}

export function createBars(canvas, tooltip) {
  const stage = canvas.parentElement;
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  const labels = new CSS2DRenderer();
  Object.assign(labels.domElement.style, { position: "absolute", inset: "0", pointerEvents: "none" });
  stage.appendChild(labels.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);
  camera.position.set(0, 8.2, 10.5);
  const controls = new OrbitControls(camera, canvas);
  controls.enableDamping = true;
  controls.enableZoom = false;
  controls.autoRotate = true;
  controls.autoRotateSpeed = 0.5;   // sways +-25 deg around the front view (see loop)
  controls.maxPolarAngle = 1.3;

  scene.add(new THREE.AmbientLight(0xf6e7da, 0.7));
  const key = new THREE.DirectionalLight(0xffffff, 1.5);
  key.position.set(5, 10, 6);
  scene.add(key);
  const rim = new THREE.PointLight(0xb23fa3, 45, 30);
  rim.position.set(-6, 4, -6);
  scene.add(rim);

  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  composer.addPass(new UnrealBloomPass(new THREE.Vector2(1, 1), 0.3, 0.5, 0.7));
  composer.addPass(new OutputPass());

  const group = new THREE.Group();
  scene.add(group);
  let mesh = null, cells = [], grow = 0;

  function clear() {
    for (const o of [...group.children]) {
      o.traverse((c) => { if (c.isCSS2DObject) c.element.remove(); });
      group.remove(o);
      o.geometry?.dispose?.();
    }
    mesh = null; cells = [];
  }

  function label(text, cls, x, y, z) {
    const el = document.createElement("div");
    el.className = "bench-label " + cls;
    if (cls === "col") el.innerHTML = `<span>${text}</span>`;
    else el.textContent = text;
    const o = new CSS2DObject(el);
    o.position.set(x, y, z);
    group.add(o);
  }

  function setData(rows, attacks) {
    clear();
    const cols = [{ name: "clean", label: "No attack" }, ...attacks];
    const nx = cols.length, nz = rows.length, gap = 0.92, w = 0.62, H = 2.3;
    const ox = -((nx - 1) * gap) / 2, oz = -((nz - 1) * gap * 1.5) / 2;

    const geo = new THREE.BoxGeometry(w, 1, w);
    geo.translate(0, 0.5, 0);
    const mat = new THREE.MeshStandardMaterial({ roughness: 0.5, metalness: 0.05 });
    mesh = new THREE.InstancedMesh(geo, mat, nx * nz);
    mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    rows.forEach((r, iz) => {
      cols.forEach((c, ix) => {
        const v = c.name === "clean" ? r.clean : r.attacks[c.name];
        const i = iz * nx + ix;
        cells[i] = { x: ox + ix * gap, z: oz + iz * gap * 1.5, h: Math.max(0.03, v) * H, v, row: r, col: c };
        mesh.setColorAt(i, scoreColor(v));
      });
    });
    group.add(mesh);

    // glowing base plate + grid
    const plate = new THREE.Mesh(new THREE.PlaneGeometry(nx * gap + 1, nz * gap * 1.5 + 1),
      new THREE.MeshBasicMaterial({ color: 0x151517, transparent: true, opacity: 0.9 }));
    plate.rotation.x = -Math.PI / 2;
    plate.position.y = -0.01;
    group.add(plate);
    const edges = new THREE.LineSegments(new THREE.EdgesGeometry(plate.geometry),
      new THREE.LineBasicMaterial({ color: 0xf4c7b8, transparent: true, opacity: 0.45 }));
    edges.rotation.x = -Math.PI / 2;
    group.add(edges);
    for (const lvl of [0.5, 1]) {   // reference rings at score 0.5 and 1.0
      const frame = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.PlaneGeometry(nx * gap, nz * gap * 1.5)),
        new THREE.LineBasicMaterial({ color: lvl === 1 ? 0x5b8db8 : 0xe3b04b, transparent: true, opacity: 0.5 }));
      frame.rotation.x = -Math.PI / 2;
      frame.position.y = lvl * H;
      group.add(frame);
      label(lvl.toFixed(1), "", ox - gap, lvl * H, oz - 0.6);
    }

    rows.forEach((r, iz) => label(r.title.replace(/ \(.*\)/, ""), "row", ox - gap * 1.6, 0.05, oz + iz * gap * 1.5));
    cols.forEach((c, ix) => label(c.label, "col", ox + ix * gap, 0.05, oz + nz * gap * 1.5 - 0.1));

    grow = 0;
    controls.target.set(0, 0.6, 0.3);
  }

  const dummy = new THREE.Object3D();
  function layout() {
    if (!mesh) return;
    cells.forEach((c, i) => {
      const t = Math.min(1, Math.max(0, grow * 1.6 - (c.x + c.z * 0.3 + 6) * 0.06));
      const e = 1 - Math.pow(1 - t, 3);
      dummy.position.set(c.x, 0, c.z);
      dummy.scale.set(1, Math.max(0.001, c.h * e), 1);
      dummy.updateMatrix();
      mesh.setMatrixAt(i, dummy.matrix);
    });
    mesh.instanceMatrix.needsUpdate = true;
  }

  // hover
  const ray = new THREE.Raycaster(), mouse = new THREE.Vector2();
  let hovered = -1;
  canvas.addEventListener("pointermove", (ev) => {
    if (!mesh) return;
    const r = canvas.getBoundingClientRect();
    mouse.set(((ev.clientX - r.left) / r.width) * 2 - 1, -((ev.clientY - r.top) / r.height) * 2 + 1);
    ray.setFromCamera(mouse, camera);
    const hit = ray.intersectObject(mesh)[0];
    if (hovered >= 0) mesh.setColorAt(hovered, scoreColor(cells[hovered].v));
    hovered = hit ? hit.instanceId : -1;
    if (hovered >= 0) {
      const c = cells[hovered];
      mesh.setColorAt(hovered, new THREE.Color(0xf6e7da));
      tooltip.innerHTML = `${c.row.title}<br>${c.col.label}: <b>${c.v.toFixed(3)}</b>`;
      tooltip.style.display = "block";
      tooltip.style.left = ev.clientX + "px";
      tooltip.style.top = ev.clientY + "px";
      controls.autoRotate = false;
    } else {
      tooltip.style.display = "none";
    }
    mesh.instanceColor.needsUpdate = true;
  });
  canvas.addEventListener("pointerleave", () => { tooltip.style.display = "none"; controls.autoRotate = true; });

  function resize() {
    const w = stage.clientWidth, h = stage.clientHeight;
    renderer.setSize(w, h, false);
    composer.setSize(w, h);
    labels.setSize(w, h);
    camera.aspect = w / h;
    camera.position.setLength(w < 700 ? 17 : 13.5);
    camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(stage);
  resize();

  let visible = false;
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; }).observe(stage);
  const clock = new THREE.Clock();
  renderer.setAnimationLoop(() => {
    const dt = Math.min(clock.getDelta(), 0.05);
    if (!visible) return;
    if (mesh && grow < 2) { grow += dt * 0.7; layout(); }
    const az = controls.getAzimuthalAngle();
    if (controls.autoRotate && Math.abs(az) > 0.45 && Math.sign(az) === -Math.sign(controls.autoRotateSpeed)) {
      controls.autoRotateSpeed *= -1;
    }
    controls.update();
    composer.render();
    labels.render(scene, camera);
  });

  return { setData };
}
