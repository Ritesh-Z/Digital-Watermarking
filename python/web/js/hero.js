// 3-D hero: the cover image as a point-cloud terrain.
//   height  = pixel brightness
//   colour  = the real pixel colour
//   glow    = watermark energy |watermarked - cover|, pooled per point
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";

const VERT = /* glsl */ `
  attribute float aHeight;
  attribute float aEnergy;
  attribute vec3 aColor;
  uniform float uTime, uLift, uEnergyMix, uScale, uSpacing, uIntro;
  varying vec3 vColor;
  varying float vGlow;
  void main() {
    vec3 p = position;
    float lift = uLift * uIntro;
    float wave = (sin(p.x * 3.1 + uTime * 0.8) + cos(p.z * 2.7 + uTime * 0.6)) * 0.018;
    p.y = aHeight * 0.55 * lift + wave * lift;

    // embedding scan line sweeping across the image
    float scanPos = mod(uTime * 0.22, 1.6) * 2.0 - 1.6;
    float scan = smoothstep(0.07, 0.0, abs(p.z - scanPos));

    float e = pow(aEnergy, 1.6) * uEnergyMix;
    p.y += e * 0.32 * uIntro + scan * 0.025;
    // warm amber -> bright gold, like light at the tip of a fibre
    // retro coral -> peach glow
    vec3 hot = mix(vec3(0.91, 0.25, 0.12), vec3(1.0, 0.72, 0.62), smoothstep(0.2, 1.0, aEnergy));
    vec3 base = aColor * 1.25 * mix(1.0, 0.18, uEnergyMix);
    vColor = base + hot * e * 1.4 + vec3(0.95, 0.55, 0.48) * scan * 0.35;
    vGlow = e;

    // intro: the photo flies in from a scattered cloud
    vec3 scatter = vec3(sin(position.z * 91.7), cos(position.x * 57.3), sin(position.x * 37.1 + position.z * 11.0)) * 1.8;
    p = mix(p + scatter, p, uIntro);

    vec4 mv = modelViewMatrix * vec4(p, 1.0);
    gl_PointSize = uScale * uSpacing * (1.15 + e * 1.4) / -mv.z;
    gl_Position = projectionMatrix * mv;
  }`;

const FRAG = /* glsl */ `
  varying vec3 vColor;
  varying float vGlow;
  void main() {
    vec2 c = gl_PointCoord - 0.5;
    float d = length(c);
    if (d > 0.5) discard;
    float a = smoothstep(0.5, 0.32, d);
    gl_FragColor = vec4(vColor, a);
  }`;

export function createHero(canvas) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, alpha: true, powerPreference: "high-performance" });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.75));
  renderer.setClearColor(0x000000, 0);   // transparent: the poster's starry black shows through

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(42, 1, 0.05, 50);
  camera.position.set(0.4, 2.55, 3.35);

  const controls = new OrbitControls(camera, canvas);
  controls.enableDamping = true;
  controls.dampingFactor = 0.06;
  controls.enableZoom = false;
  controls.enablePan = false;
  controls.autoRotate = true;
  controls.autoRotateSpeed = 0.45;
  controls.minPolarAngle = 0.25;
  controls.maxPolarAngle = 1.35;
  controls.target.set(0, 0.12, 0);

  // ---- terrain points
  const uniforms = {
    uTime: { value: 0 }, uLift: { value: 1 }, uEnergyMix: { value: 0 },
    uScale: { value: 600 }, uSpacing: { value: 0.015 }, uIntro: { value: 0 },
  };
  const material = new THREE.ShaderMaterial({
    vertexShader: VERT, fragmentShader: FRAG, uniforms,
    transparent: true, depthWrite: true,
  });
  let points = null;

  function build(n, rgb, height, energy) {
    if (points) { points.geometry.dispose(); scene.remove(points); }
    const count = n * n;
    const pos = new Float32Array(count * 3);
    const col = new Float32Array(count * 3);
    const h = new Float32Array(count);
    const e = new Float32Array(count);
    const span = 2.4;
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        const i = r * n + c;
        pos[i * 3] = (c / (n - 1) - 0.5) * span;
        pos[i * 3 + 2] = (r / (n - 1) - 0.5) * span;
        const lin = (v) => Math.pow(v / 255, 2.2);   // sRGB -> linear (OutputPass converts back)
        col[i * 3] = lin(rgb[i * 3]);
        col[i * 3 + 1] = lin(rgb[i * 3 + 1]);
        col[i * 3 + 2] = lin(rgb[i * 3 + 2]);
        h[i] = height[i] / 255;
        e[i] = energy[i] / 255;
      }
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute("position", new THREE.BufferAttribute(pos, 3));
    g.setAttribute("aColor", new THREE.BufferAttribute(col, 3));
    g.setAttribute("aHeight", new THREE.BufferAttribute(h, 1));
    g.setAttribute("aEnergy", new THREE.BufferAttribute(e, 1));
    points = new THREE.Points(g, material);
    uniforms.uSpacing.value = span / (n - 1);
    scene.add(points);
  }

  // placeholder terrain until the first result arrives
  {
    const n = 120, rgb = new Uint8Array(n * n * 3), hh = new Uint8Array(n * n), ee = new Uint8Array(n * n);
    for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) {
      const i = r * n + c, v = 0.5 + 0.5 * Math.sin(c * 0.11) * Math.cos(r * 0.09);
      rgb[i * 3] = 70 + 110 * v; rgb[i * 3 + 1] = 66 + 96 * v; rgb[i * 3 + 2] = 60 + 80 * v;
      hh[i] = 255 * v; ee[i] = 0;
    }
    build(n, rgb, hh, ee);
  }

  // ---- warm dust: a few amber motes drifting up around the terrain
  const dustN = 260, dustPos = new Float32Array(dustN * 3), dustSpeed = new Float32Array(dustN);
  for (let i = 0; i < dustN; i++) {
    dustPos[i * 3] = (Math.random() - 0.5) * 4.2;
    dustPos[i * 3 + 1] = Math.random() * 1.8 - 0.1;
    dustPos[i * 3 + 2] = (Math.random() - 0.5) * 4.2;
    dustSpeed[i] = 0.02 + Math.random() * 0.06;
  }
  const dustGeo = new THREE.BufferGeometry();
  dustGeo.setAttribute("position", new THREE.BufferAttribute(dustPos, 3));
  const dust = new THREE.Points(dustGeo, new THREE.PointsMaterial({
    color: 0xf4c7b8, size: 0.02, transparent: true, opacity: 0.8, depthWrite: false }));
  scene.add(dust);

  // ---- base grid
  const grid = new THREE.GridHelper(3.4, 34, 0x5b8db8, 0x2a3f55);
  grid.position.set(0, -0.02, 0);
  grid.material.transparent = true;
  grid.material.opacity = 0.35;
  scene.add(grid);

  // ---- post-processing
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.5, 0.5, 0.8);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());

  function resize() {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    composer.setSize(w, h);
    camera.aspect = w / h;
    // keep the whole terrain in frame on tall/narrow screens
    const dir = camera.position.clone().sub(controls.target);
    dir.setLength(4.25 * Math.max(1, 1.3 / camera.aspect) ** 0.85);
    camera.position.copy(controls.target).add(dir);
    uniforms.uScale.value = (h * renderer.getPixelRatio()) / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)));
    // wide screens: shift the rendered view right (text sits on the left)
    // with a view offset, so the terrain still orbits around its own centre
    // lift the terrain above the magenta band (and right of the caption on wide screens)
    if (w >= 960) camera.setViewOffset(w, h, -w * 0.1, h * 0.13, w, h);
    else camera.setViewOffset(w, h, 0, h * 0.12, w, h);
    camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(canvas);
  resize();

  // ---- modes
  const targets = { lift: 1, energy: 0, bloom: 0.5 };
  const MODES = {
    photo: { lift: 0, energy: 0, bloom: 0.3 },
    terrain: { lift: 1, energy: 0, bloom: 0.5 },
    energy: { lift: 0.55, energy: 1, bloom: 1.0 },
  };
  function setMode(m) { Object.assign(targets, MODES[m]); }

  // ---- loop (paused when off-screen)
  let visible = true;
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; }).observe(canvas);
  const clock = new THREE.Clock();
  let introStart = performance.now();
  const ease = (a, b, k) => a + (b - a) * k;
  renderer.setAnimationLoop(() => {
    if (!visible) return;
    const dt = Math.min(clock.getDelta(), 0.05);
    uniforms.uTime.value += dt;
    const t = (performance.now() - introStart) / 2600;          // 2.6 s fly-in, frame-rate independent
    uniforms.uIntro.value = t >= 1 ? 1 : 1 - Math.pow(1 - Math.max(0, t), 3);
    const k = 1 - Math.pow(0.02, dt);
    uniforms.uLift.value = ease(uniforms.uLift.value, targets.lift, k);
    uniforms.uEnergyMix.value = ease(uniforms.uEnergyMix.value, targets.energy, k);
    bloom.strength = ease(bloom.strength, targets.bloom, k);
    for (let i = 0; i < dustN; i++) {
      dustPos[i * 3 + 1] += dustSpeed[i] * dt;
      if (dustPos[i * 3 + 1] > 1.8) dustPos[i * 3 + 1] = -0.1;
    }
    dustGeo.attributes.position.needsUpdate = true;
    controls.update();
    composer.render();
  });

  return {
    setData(t) {
      const dec = (s) => Uint8Array.from(atob(s), (ch) => ch.charCodeAt(0));
      build(t.n, dec(t.rgb), dec(t.height), dec(t.energy));
      resize();
    },
    setMode,
  };
}
