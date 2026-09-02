import qrcode from "../vendor/qrcode";

// "Point at Satellite" fullscreen sky view.
//
// Uses the phone's compass + accelerometer (deviceorientation) to render an
// artificial horizon that matches the phone's orientation in space — the view
// points out of the TOP of the phone, so you aim by pointing the phone's top
// edge at the satellite — with the pass path and the satellite's live
// position drawn in the sky. Live position
// arrives via the "move_satellite" events pushed every second by the
// PassTracker LiveComponent on the same page (filtered by data-tracker-id).

const SKY_TOP_COLOR = "#7dd3fc"; // sky-300
const SKY_BOTTOM_COLOR = "#bae6fd"; // sky-200
const GROUND_NEAR_COLOR = "#16a34a"; // green-600, at the horizon
const GROUND_FAR_COLOR = "#14532d"; // green-900, underfoot
const HORIZON_COLOR = "rgba(255, 255, 255, 0.9)";
const GUIDE_COLOR = "rgba(255, 255, 255, 0.4)";
const GRID_COLOR = "rgba(255, 255, 255, 0.3)";
const LABEL_COLOR = "#FFFFFF";
const SATELLITE_COLOR = "#2563EB"; // blue-700, matches the polar plot
const PATH_COLOR = SATELLITE_COLOR;
const HIDDEN_SATELLITE_COLOR = "rgb(220, 38, 38)"; // red-600, matches the polar plot
const LOCKED_COLOR = "#059669"; // emerald-600
const DEG = Math.PI / 180;
const VERTICAL_FOV = 65 * DEG;
const LOCKED_ANGLE = 3 * DEG;
const SAT_RADIUS = 14;
const START_HEAD_SIZE = 6;
const ARROW_SIZE = 14;
const EDGE_ARROW_MARGIN = 44;
const SMOOTHING_TIME_CONSTANT = 0.12; // seconds; smaller = snappier

export default {
  mounted() {
    this.path = JSON.parse(this.el.dataset.path);
    this.trackerId = this.el.dataset.trackerId;
    this.satName = this.el.dataset.satName;
    this.satPos = {
      az: parseFloat(this.el.dataset.initialAz),
      el: parseFloat(this.el.dataset.initialEl),
    };
    this.orientation = null;
    this.overlay = null;

    this.handleEvent("move_satellite", ({ id, az, el }) => {
      if (id !== this.trackerId) return;
      this.satPos = { az, el };
    });

    this.el
      .querySelector("[data-sky-view-open]")
      .addEventListener("click", () => this.openOverlay());

    // Arriving via the QR code in the unsupported-device modal (?sky=1):
    // open the sky view right away. iOS only shows the motion-permission
    // prompt from within a tap, so there we interpose a one-tap modal.
    if (new URLSearchParams(window.location.search).has("sky") && isSupported()) {
      if (typeof DeviceOrientationEvent.requestPermission === "function") {
        this.showModal(
          "Your phone will ask for motion " +
          "access so the view can follow where you point.",
          { action: { label: "Open Sky View", onClick: () => this.openOverlay() } }
        );
      } else {
        this.openOverlay();
      }
    }
  },

  destroyed() {
    this.closeOverlay();
  },

  async openOverlay() {
    if (this.overlay) return;

    if (!isSupported()) {
      const qrUrl = new URL(window.location.href);
      qrUrl.searchParams.set("sky", "1");
      this.showModal(
        "Use your phone's compass and motion sensors to " +
        "locate the satellite:",
        { qrUrl: qrUrl.toString() }
      );
      return;
    }

    // iOS 13+ requires asking permission from within the tap gesture
    if (typeof DeviceOrientationEvent.requestPermission === "function") {
      let state;
      try {
        state = await DeviceOrientationEvent.requestPermission();
      } catch (_e) {
        state = "denied";
      }

      if (state !== "granted") {
        this.showModal(
          "Motion access was denied, so the sky view can't follow your " +
          "phone. Enable it in Settings → Safari → Motion & Orientation " +
          "Access, then reload this page."
        );
        return;
      }
    }

    this.buildSkyOverlay();
    this.startSensors();
    this.raf = requestAnimationFrame(() => this.frame());
  },

  showModal(text, opts = {}) {
    const overlay = document.createElement("div");
    overlay.className =
      "fixed inset-0 z-[2000] bg-black/60 flex items-center justify-center p-6";

    const card = document.createElement("div");
    card.className =
      "bg-white rounded-lg shadow-xl max-w-sm w-full p-6 flex flex-col gap-4";

    const message = document.createElement("div");
    message.className = "text-gray-700";
    message.textContent = text;

    let qrContainer = null;
    if (opts.qrUrl) {
      qrContainer = document.createElement("div");
      qrContainer.className = "mx-auto w-44 h-44 my-2";
      const qr = qrcode(0, "M");
      qr.addData(opts.qrUrl);
      qr.make();
      qrContainer.innerHTML = qr.createSvgTag({
        cellSize: 4,
        margin: 0,
        scalable: true,
      });
      qrContainer.firstElementChild.setAttribute("width", "100%");
      qrContainer.firstElementChild.setAttribute("height", "100%");
    }

    const close = document.createElement("button");
    close.type = "button";
    close.className = "btn btn-default w-full justify-center text-center";
    close.textContent = "Close";
    close.addEventListener("click", () => this.closeOverlay());

    card.appendChild(message);
    if (qrContainer) card.appendChild(qrContainer);
    if (opts.action) {
      const action = document.createElement("button");
      action.type = "button";
      action.className = "btn btn-green border-transparent w-full justify-center text-center";
      action.textContent = opts.action.label;
      action.addEventListener("click", () => {
        this.closeOverlay();
        opts.action.onClick();
      });
      card.appendChild(action);
    }
    card.appendChild(close);
    overlay.appendChild(card);
    this.openLayer(overlay);
  },

  buildSkyOverlay() {
    const overlay = document.createElement("div");
    overlay.className =
      "fixed inset-0 z-[2000] bg-sky-300 touch-none overscroll-contain select-none";

    this.canvas = document.createElement("canvas");
    this.canvas.className = "absolute inset-0 w-full h-full block";
    overlay.appendChild(this.canvas);

    const hud = document.createElement("div");
    hud.className =
      "absolute top-0 inset-x-0 flex items-center gap-3 px-4 py-3 bg-black/30 text-white";

    const name = document.createElement("div");
    name.className =
      "text-lg font-semibold leading-none whitespace-nowrap overflow-hidden text-ellipsis";
    name.textContent = this.satName;

    this.hudReadout = document.createElement("div");
    this.hudReadout.className = "ml-auto tabular-nums whitespace-nowrap text-base leading-none";
    this.hudText = null;

    const close = document.createElement("button");
    close.type = "button";
    close.className =
      "shrink-0 -my-2 -mr-2 h-12 w-12 flex items-center justify-center text-4xl leading-none";
    close.setAttribute("aria-label", "Close sky view");
    close.textContent = "✕";
    close.addEventListener("click", () => this.closeOverlay());

    hud.appendChild(name);
    hud.appendChild(this.hudReadout);
    hud.appendChild(close);
    overlay.appendChild(hud);

    this.openLayer(overlay);

    this.ctx = this.canvas.getContext("2d");
    this.resizeCanvas();
    this.onResize = () => this.resizeCanvas();
    window.addEventListener("resize", this.onResize);
  },

  openLayer(overlay) {
    this.overlay = overlay;
    this.savedBodyOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    document.body.appendChild(overlay);
  },

  closeOverlay() {
    if (this.raf) {
      cancelAnimationFrame(this.raf);
      this.raf = null;
    }
    if (this.noDataTimer) {
      clearTimeout(this.noDataTimer);
      this.noDataTimer = null;
    }
    if (this.onOrientation) {
      window.removeEventListener(this.orientationEventName, this.onOrientation);
      this.onOrientation = null;
    }
    if (this.onResize) {
      window.removeEventListener("resize", this.onResize);
      this.onResize = null;
    }
    if (this.overlay) {
      this.overlay.remove();
      this.overlay = null;
      document.body.style.overflow = this.savedBodyOverflow || "";
    }
    this.orientation = null;
    this.smoothR = null;
    this.lastSmoothTime = null;
  },

  startSensors() {
    this.onOrientation = (e) => {
      if (e.alpha == null && e.webkitCompassHeading == null) return;

      let alpha = e.alpha;
      if (e.webkitCompassHeading != null) {
        // iOS: alpha has an arbitrary origin, but webkitCompassHeading gives
        // degrees clockwise from magnetic north, so substitute it to keep the
        // view world-aligned. Magnetic declination (typically < 15°) is
        // knowingly ignored.
        alpha = 360 - e.webkitCompassHeading;
      }

      this.orientation = {
        alpha: alpha * DEG,
        beta: (e.beta || 0) * DEG,
        gamma: (e.gamma || 0) * DEG,
      };
    };

    // Android only reports a world-referenced alpha on the "absolute" event
    this.orientationEventName =
      "ondeviceorientationabsolute" in window
        ? "deviceorientationabsolute"
        : "deviceorientation";
    window.addEventListener(this.orientationEventName, this.onOrientation);

    // Backstop for devices that pass feature detection but never deliver data
    this.noDataTimer = setTimeout(() => {
      this.noDataTimer = null;
      if (!this.orientation) {
        this.closeOverlay();
        const qrUrl = new URL(window.location.href);
        qrUrl.searchParams.set("sky", "1");
        this.showModal(
          "No compass data is available on this device. Use your phone's " +
            "compass and motion sensors to locate the satellite:",
          { qrUrl: qrUrl.toString() }
        );
      }
    }, 2000);
  },

  resizeCanvas() {
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = Math.round(this.canvas.clientWidth * dpr);
    this.canvas.height = Math.round(this.canvas.clientHeight * dpr);
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  },

  frame() {
    this.raf = requestAnimationFrame(() => this.frame());
    this.draw();
  },

  draw() {
    const ctx = this.ctx;
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;

    const gradient = ctx.createLinearGradient(0, 0, 0, h);
    gradient.addColorStop(0, SKY_TOP_COLOR);
    gradient.addColorStop(1, SKY_BOTTOM_COLOR);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, w, h);

    if (!this.orientation) {
      ctx.fillStyle = HORIZON_COLOR;
      ctx.font = "20px sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("Waiting for compass data…", w / 2, h / 2);
      return;
    }

    const cam = this.makeCamera(w, h);
    this.drawGround(cam);
    this.drawSkyGrid(cam);
    this.drawElevationGuides(cam);
    this.drawHorizon(cam);
    this.drawCardinals(cam);
    this.drawPath(cam);
    const lockedOn = this.drawSatellite(cam);
    this.drawCrosshair(cam, lockedOn);
    this.updateHud();
  },

  makeCamera(w, h) {
    const { alpha, beta, gamma } = this.orientation;
    const cA = Math.cos(alpha);
    const sA = Math.sin(alpha);
    const cB = Math.cos(beta);
    const sB = Math.sin(beta);
    const cG = Math.cos(gamma);
    const sG = Math.sin(gamma);

    // Device→Earth rotation (W3C ZXY intrinsic; Earth frame X=east, Y=north,
    // Z=up; device frame x=right, y=top of screen, z=out of the screen)
    const target = [
      [cA * cG - sA * sB * sG, -sA * cB, cA * sG + sA * sB * cG],
      [sA * cG + cA * sB * sG, cA * cB, sA * sG - cA * sB * cG],
      [-cB * sG, sB, cB * cG],
    ];

    // Compass readings are jumpy, so ease the displayed rotation toward the
    // sensor's rotation each frame. Smoothing happens in matrix space —
    // smoothing the Euler angles themselves breaks at the 0°/360° compass
    // wrap — with the result re-orthonormalized to stay a valid rotation.
    const now = performance.now();
    const dt = this.lastSmoothTime
      ? Math.min((now - this.lastSmoothTime) / 1000, 0.1)
      : 0;
    this.lastSmoothTime = now;

    if (!this.smoothR) {
      this.smoothR = target;
    } else {
      const k = 1 - Math.exp(-dt / SMOOTHING_TIME_CONSTANT);
      for (let i = 0; i < 3; i++) {
        for (let j = 0; j < 3; j++) {
          this.smoothR[i][j] += k * (target[i][j] - this.smoothR[i][j]);
        }
      }
      if (!orthonormalize(this.smoothR)) {
        this.smoothR = target;
      }
    }
    const r = this.smoothR;

    // Compensate for screen rotation in landscape. If landscape rendering
    // comes out rotated the wrong way on some browser, flip theta's sign.
    const angle =
      (screen.orientation && screen.orientation.angle) ?? window.orientation ?? 0;
    const theta = angle * DEG;

    return {
      r,
      cosT: Math.cos(theta),
      sinT: Math.sin(theta),
      w,
      h,
      cx: w / 2,
      cy: h / 2,
      f: h / 2 / Math.tan(VERTICAL_FOV / 2),
    };
  },

  // Projects an azimuth/elevation (degrees) into screen space. `front` is
  // whether the direction is in front of the camera; `visible` additionally
  // requires the projected point to be within sane bounds (near the view
  // plane, projected coordinates blow up).
  project(cam, azDeg, elDeg) {
    const az = azDeg * DEG;
    const el = elDeg * DEG;

    // Unit vector in the Earth frame (east, north, up)
    const d = [
      Math.sin(az) * Math.cos(el),
      Math.cos(az) * Math.cos(el),
      Math.sin(el),
    ];

    // World → device frame: v = Rᵀ·d
    const r = cam.r;
    const vx = r[0][0] * d[0] + r[1][0] * d[1] + r[2][0] * d[2];
    const vy = r[0][1] * d[0] + r[1][1] * d[1] + r[2][1] * d[2];
    const vz = r[0][2] * d[0] + r[1][2] * d[1] + r[2][2] * d[2];

    // The view points out of the TOP of the device (device +y), so you aim
    // by pointing the top edge of the phone at the satellite: screen right =
    // device x, screen up = device z (out of the screen face), and depth
    // along the pointing direction is vy. Rotate the screen-plane pair into
    // the current screen orientation.
    const xs = vx * cam.cosT + vz * cam.sinT;
    const ys = -vx * cam.sinT + vz * cam.cosT;
    const depth = vy;

    const point = { depth, xs, ys, front: depth > 0.01, visible: false, x: 0, y: 0 };
    if (point.front) {
      point.x = cam.cx + (cam.f * xs) / depth;
      point.y = cam.cy - (cam.f * ys) / depth;
      point.visible =
        Math.abs(point.x - cam.cx) < cam.w * 4 &&
        Math.abs(point.y - cam.cy) < cam.h * 4;
    }
    return point;
  },

  strokeSkyPolyline(cam, coords, strokeStyle, lineWidth) {
    const ctx = this.ctx;
    ctx.strokeStyle = strokeStyle;
    ctx.lineWidth = lineWidth;
    ctx.beginPath();
    let prev = null;
    for (const coord of coords) {
      const p = this.project(cam, coord.az, coord.el);
      if (p.visible && prev && prev.visible) {
        ctx.moveTo(prev.x, prev.y);
        ctx.lineTo(p.x, p.y);
      }
      prev = p;
    }
    ctx.stroke();
  },

  // Fills everything below the horizon in brown, like an attitude indicator.
  // A screen pixel maps to the view direction ((x−cx)/f, (cy−y)/f, 1) in
  // (right, up, forward) coordinates, and its elevation sign is the dot
  // product with the world-up vector — so in a perspective projection the
  // horizon is an exact straight line, and the ground is the half-plane
  // A·x + B·y + C < 0 clipped to the canvas.
  drawGround(cam) {
    const ctx = this.ctx;
    const r = cam.r;

    // World-up in device coordinates is the third row of R; map it into
    // screen space the same way project() does
    const ux = r[2][0] * cam.cosT + r[2][2] * cam.sinT;
    const uy = -r[2][0] * cam.sinT + r[2][2] * cam.cosT;
    const ud = r[2][1];

    const A = ux;
    const B = -uy;
    const C = -ux * cam.cx + uy * cam.cy + cam.f * ud;

    // Sutherland–Hodgman clip of the canvas rect against the ground half-plane
    const corners = [
      [0, 0],
      [cam.w, 0],
      [cam.w, cam.h],
      [0, cam.h],
    ];
    const poly = [];
    for (let i = 0; i < 4; i++) {
      const p = corners[i];
      const q = corners[(i + 1) % 4];
      const fp = A * p[0] + B * p[1] + C;
      const fq = A * q[0] + B * q[1] + C;
      if (fp < 0) poly.push(p);
      if (fp < 0 !== fq < 0) {
        const t = fp / (fp - fq);
        poly.push([p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])]);
      }
    }
    if (poly.length < 3) return;

    // Shade from lighter at the horizon to darker underfoot
    const norm = Math.hypot(A, B);
    let fill = GROUND_FAR_COLOR;
    if (norm > 1e-6) {
      const t0 = -(A * cam.cx + B * cam.cy + C) / (norm * norm);
      const x0 = cam.cx + A * t0;
      const y0 = cam.cy + B * t0;
      const reach = Math.max(cam.w, cam.h);
      const gradient = ctx.createLinearGradient(
        x0,
        y0,
        x0 - (A / norm) * reach,
        y0 - (B / norm) * reach
      );
      gradient.addColorStop(0, GROUND_NEAR_COLOR);
      gradient.addColorStop(1, GROUND_FAR_COLOR);
      fill = gradient;
    }

    ctx.fillStyle = fill;
    ctx.beginPath();
    ctx.moveTo(poly[0][0], poly[0][1]);
    for (let i = 1; i < poly.length; i++) {
      ctx.lineTo(poly[i][0], poly[i][1]);
    }
    ctx.closePath();
    ctx.fill();
  },

  drawHorizon(cam) {
    const coords = [];
    for (let az = 0; az <= 360; az += 5) {
      coords.push({ az, el: 0 });
    }
    const ctx = this.ctx;
    ctx.save();
    ctx.shadowColor = "rgba(0, 0, 0, 0.35)";
    ctx.shadowBlur = 4;
    this.strokeSkyPolyline(cam, coords, HORIZON_COLOR, 2.5);
    ctx.restore();
  },

  // Faint grid over the sky: elevation circles and azimuth meridians every
  // 10°. Meridians stop at 80° so they don't pile up at the zenith; the 30°
  // and 60° circles are drawn brighter by drawElevationGuides.
  drawSkyGrid(cam) {
    for (let el = 10; el <= 80; el += 10) {
      if (el % 30 === 0) continue;
      const coords = [];
      for (let az = 0; az <= 360; az += 10) {
        coords.push({ az, el });
      }
      this.strokeSkyPolyline(cam, coords, GRID_COLOR, 1);
    }

    for (let az = 0; az < 360; az += 10) {
      const coords = [];
      for (let el = 0; el <= 80; el += 5) {
        coords.push({ az, el });
      }
      this.strokeSkyPolyline(cam, coords, GRID_COLOR, 1);
    }
  },

  drawElevationGuides(cam) {
    [30, 60].forEach((el) => {
      const coords = [];
      for (let az = 0; az <= 360; az += 10) {
        coords.push({ az, el });
      }
      this.strokeSkyPolyline(cam, coords, GUIDE_COLOR, 1.5);
    });

    // Small cross at the zenith
    const zenith = this.project(cam, 0, 90);
    if (zenith.visible) {
      const ctx = this.ctx;
      ctx.strokeStyle = GUIDE_COLOR;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(zenith.x - 8, zenith.y);
      ctx.lineTo(zenith.x + 8, zenith.y);
      ctx.moveTo(zenith.x, zenith.y - 8);
      ctx.lineTo(zenith.x, zenith.y + 8);
      ctx.stroke();
    }
  },

  drawCardinals(cam) {
    const ctx = this.ctx;
    const cardinals = [
      { az: 0, label: "N" },
      { az: 45, label: "NE" },
      { az: 90, label: "E" },
      { az: 135, label: "SE" },
      { az: 180, label: "S" },
      { az: 225, label: "SW" },
      { az: 270, label: "W" },
      { az: 315, label: "NW" },
    ];

    ctx.save();
    ctx.shadowColor = "rgba(0, 0, 0, 0.4)";
    ctx.shadowBlur = 4;
    ctx.textAlign = "center";
    ctx.textBaseline = "bottom";

    cardinals.forEach(({ az, label }) => {
      const base = this.project(cam, az, 0);
      const tickTop = this.project(cam, az, 2.5);
      const labelPos = this.project(cam, az, 6);
      if (!base.visible || !tickTop.visible || !labelPos.visible) return;

      ctx.strokeStyle = LABEL_COLOR;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(base.x, base.y);
      ctx.lineTo(tickTop.x, tickTop.y);
      ctx.stroke();

      ctx.fillStyle = LABEL_COLOR;
      ctx.font = label === "N" ? "bold 28px sans-serif" : "bold 20px sans-serif";
      ctx.fillText(label, labelPos.x, labelPos.y);
    });

    ctx.restore();
  },

  drawPath(cam) {
    if (this.path.length < 2) return;
    const ctx = this.ctx;

    this.strokeSkyPolyline(cam, this.path, PATH_COLOR, 3);

    // Filled circle at the start of the pass (AOS), matching the polar plot
    const start = this.project(cam, this.path[0].az, this.path[0].el);
    if (start.visible) {
      ctx.fillStyle = PATH_COLOR;
      ctx.beginPath();
      ctx.arc(start.x, start.y, START_HEAD_SIZE, 0, Math.PI * 2);
      ctx.fill();
    }

    // Arrowhead at the end of the pass (LOS)
    const last = this.project(
      cam,
      this.path[this.path.length - 1].az,
      this.path[this.path.length - 1].el
    );
    const secondLast = this.project(
      cam,
      this.path[this.path.length - 2].az,
      this.path[this.path.length - 2].el
    );
    if (last.visible && secondLast.visible) {
      const angle = Math.atan2(last.y - secondLast.y, last.x - secondLast.x);
      const tipX = last.x + 4 * Math.cos(angle);
      const tipY = last.y + 4 * Math.sin(angle);
      ctx.fillStyle = PATH_COLOR;
      ctx.beginPath();
      ctx.moveTo(tipX, tipY);
      ctx.lineTo(
        last.x - ARROW_SIZE * Math.cos(angle - Math.PI / 6),
        last.y - ARROW_SIZE * Math.sin(angle - Math.PI / 6)
      );
      ctx.lineTo(
        last.x - ARROW_SIZE * Math.cos(angle + Math.PI / 6),
        last.y - ARROW_SIZE * Math.sin(angle + Math.PI / 6)
      );
      ctx.closePath();
      ctx.fill();
    }
  },

  drawSatellite(cam) {
    const ctx = this.ctx;
    const sat = this.project(cam, this.satPos.az, this.satPos.el);
    const above = this.satPos.el >= 0;

    // Angular distance between the pointing axis and the satellite
    const offAxis = Math.acos(Math.min(1, Math.max(-1, sat.depth)));
    const lockedOn = offAxis < LOCKED_ANGLE;

    const onScreen =
      sat.front &&
      sat.x > -SAT_RADIUS &&
      sat.x < cam.w + SAT_RADIUS &&
      sat.y > -SAT_RADIUS &&
      sat.y < cam.h + SAT_RADIUS;

    if (!onScreen) {
      this.drawOffscreenArrow(cam, sat, above);
      return lockedOn;
    }

    ctx.beginPath();
    ctx.arc(sat.x, sat.y, SAT_RADIUS, 0, Math.PI * 2);
    ctx.lineWidth = 3;
    if (above) {
      ctx.setLineDash([]);
      ctx.strokeStyle = lockedOn ? LOCKED_COLOR : SATELLITE_COLOR;
      ctx.fillStyle = lockedOn
        ? "rgba(5, 150, 105, 0.25)"
        : "rgba(37, 99, 235, 0.25)";
      ctx.fill();
    } else {
      // Dotted white while below the horizon
      ctx.setLineDash([1, 6]);
      ctx.lineCap = "round";
      ctx.strokeStyle = "#FFFFFF";
    }
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.lineCap = "butt";

    ctx.save();
    ctx.shadowColor = "rgba(0, 0, 0, 0.4)";
    ctx.shadowBlur = 4;
    ctx.fillStyle = LABEL_COLOR;
    ctx.font = "600 17px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "top";
    ctx.fillText(this.satName, sat.x, sat.y + SAT_RADIUS + 6);
    ctx.restore();

    return lockedOn;
  },

  // Edge arrow showing which way to turn when the satellite is behind the
  // camera or outside the viewport. The screen-space direction (xs, −ys)
  // remains valid guidance even for directions behind the camera.
  drawOffscreenArrow(cam, sat, above) {
    const ctx = this.ctx;
    let dx = sat.xs;
    let dy = -sat.ys;
    const len = Math.hypot(dx, dy);
    if (len < 1e-6) {
      // Directly behind (or ahead): no lateral component, just point up
      dx = 0;
      dy = -1;
    } else {
      dx /= len;
      dy /= len;
    }

    // Clamp the arrow to the viewport edge along that direction
    const tx = dx !== 0 ? (cam.w / 2 - EDGE_ARROW_MARGIN) / Math.abs(dx) : Infinity;
    const ty = dy !== 0 ? (cam.h / 2 - EDGE_ARROW_MARGIN) / Math.abs(dy) : Infinity;
    const t = Math.min(tx, ty);
    const x = cam.cx + dx * t;
    const y = cam.cy + dy * t;

    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(Math.atan2(dy, dx));
    ctx.fillStyle = above ? SATELLITE_COLOR : HIDDEN_SATELLITE_COLOR;
    ctx.beginPath();
    ctx.moveTo(14, 0);
    ctx.lineTo(-8, -9);
    ctx.lineTo(-4, 0);
    ctx.lineTo(-8, 9);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  },

  drawCrosshair(cam, lockedOn) {
    const ctx = this.ctx;
    ctx.strokeStyle = lockedOn ? LOCKED_COLOR : HORIZON_COLOR;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cam.cx - 16, cam.cy);
    ctx.lineTo(cam.cx - 5, cam.cy);
    ctx.moveTo(cam.cx + 5, cam.cy);
    ctx.lineTo(cam.cx + 16, cam.cy);
    ctx.moveTo(cam.cx, cam.cy - 16);
    ctx.lineTo(cam.cx, cam.cy - 5);
    ctx.moveTo(cam.cx, cam.cy + 5);
    ctx.lineTo(cam.cx, cam.cy + 16);
    ctx.stroke();

    if (lockedOn) {
      ctx.beginPath();
      ctx.arc(cam.cx, cam.cy, 22, 0, Math.PI * 2);
      ctx.stroke();
    }
  },

  updateHud() {
    const text = `Az ${Math.round(this.satPos.az)}° · El ${Math.round(this.satPos.el)}°`;
    if (text !== this.hudText) {
      this.hudText = text;
      this.hudReadout.textContent = text;
    }
  },
};

// Gram-Schmidt on the matrix's rows, with right-handedness restored via a
// cross product. Returns false if the matrix has degenerated (rows collapsed
// during interpolation) and can't be normalized.
function orthonormalize(m) {
  const a = m[0];
  const b = m[1];

  const lenA = Math.hypot(a[0], a[1], a[2]);
  if (lenA < 1e-6) return false;
  for (let i = 0; i < 3; i++) a[i] /= lenA;

  const dot = b[0] * a[0] + b[1] * a[1] + b[2] * a[2];
  for (let i = 0; i < 3; i++) b[i] -= dot * a[i];
  const lenB = Math.hypot(b[0], b[1], b[2]);
  if (lenB < 1e-6) return false;
  for (let i = 0; i < 3; i++) b[i] /= lenB;

  m[2] = [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
  return true;
}

function isSupported() {
  if (!window.DeviceOrientationEvent) return false;
  if (typeof DeviceOrientationEvent.requestPermission === "function") return true; // iOS 13+
  // Android fires deviceorientationabsolute; desktop Chrome defines the API
  // but never delivers events, so also require an actual touch device
  // (maxTouchPoints catches touchscreen laptops that report a coarse pointer)
  return (
    "ondeviceorientationabsolute" in window &&
    navigator.maxTouchPoints > 0 &&
    window.matchMedia("(pointer: coarse)").matches
  );
}
