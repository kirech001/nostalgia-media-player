/* ============================================================
   Nostalgia Player — XP era edition
   Vanilla JS. No frameworks, no build step.
   ============================================================ */

(() => {
  "use strict";

  /* ---------------- helpers ---------------- */

  const $ = (id) => document.getElementById(id);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));
  const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

  const ipc = (msg) => {
    try {
      if (window.ipc && window.ipc.postMessage) window.ipc.postMessage(msg);
    } catch (_) { /* running outside the shell */ }
  };

  const fmtTime = (sec) => {
    if (!isFinite(sec) || sec < 0) sec = 0;
    sec = Math.floor(sec);
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = sec % 60;
    return h
      ? `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
      : `${m}:${String(s).padStart(2, "0")}`;
  };

  /* ---------------- elements ---------------- */

  const els = {
    app: $("app"),
    titlebar: $("titlebar"),
    stage: $("stage"),
    media: $("media"),
    viz: $("viz"),
    miniViz: $("console-viz"),
    playlist: $("playlist"),
    plEmpty: $("pl-empty"),
    totalTime: $("total-time"),
    trackTitle: $("track-title"),
    trackSub: $("track-sub"),
    vizName: $("viz-name"),
    statusText: $("status-text"),
    statusFmt: $("status-fmt"),
    statusExt: $("status-ext"),
    timeCur: $("time-cur"),
    timeDur: $("time-dur"),
    seekbar: $("seekbar"),
    seekFill: $("seek-fill"),
    seekThumb: $("seek-thumb"),
    volbar: $("volbar"),
    volFill: $("vol-fill"),
    volThumb: $("vol-thumb"),
    btnPlay: $("btn-play"),
    btnMute: $("btn-mute"),
    clock: $("clock"),
    fileInput: $("file-input"),
    dirInput: $("dir-input"),
    about: $("about"),
    btnPlAdd: $("btn-pl-add"),
    btnPlClear: $("btn-pl-clear"),
  };
  /* ---------------- state ---------------- */

  const MODES = ["Bars", "Waves", "Ambience"];
  const MEDIA_RE = /\.(mp3|wav|flac|ogg|oga|opus|m4a|aac|wma|mp4|m4v|webm|mkv|avi|wmv|mov|mpg|mpeg|ts)$/i;
  const VIDEO_RE = /\.(mp4|m4v|webm|mkv|avi|wmv|mov|mpg|mpeg|ts)$/i;

  const state = {
    tracks: [],
    current: -1,
    playing: false,
    mode: 0,
    theater: false,
    volume: 0.8,
    muted: false,
  };

  let seq = 0;

  /* ---------------- audio graph ---------------- */

  let actx = null;
  let analyser = null;
  let freqData = new Uint8Array(512);
  let waveData = new Uint8Array(1024);
  let audioReady = false;

  function ensureAudio() {
    if (audioReady) {
      if (actx && actx.state === "suspended") actx.resume().catch(() => {});
      return;
    }
    try {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      actx = new AC();
      const source = actx.createMediaElementSource(els.media);
      analyser = actx.createAnalyser();
      analyser.fftSize = 2048;
      analyser.smoothingTimeConstant = 0.82;
      source.connect(analyser);
      analyser.connect(actx.destination);
      freqData = new Uint8Array(analyser.frequencyBinCount);
      waveData = new Uint8Array(analyser.fftSize);
      audioReady = true;
    } catch (_) {
      audioReady = false;
    }
    if (actx && actx.state === "suspended") actx.resume().catch(() => {});
  }

  document.addEventListener("pointerdown", ensureAudio, true);

  /* ---------------- media helpers ---------------- */

  function isMediaFile(file) {
    return (
      (file.type && (file.type.startsWith("audio/") || file.type.startsWith("video/"))) ||
      MEDIA_RE.test(file.name)
    );
  }

  function parseName(name) {
    const base = name.replace(/\.[^.]+$/, "").replace(/_/g, " ").trim();
    const parts = base.split(/\s+-\s+/);
    if (parts.length >= 2) {
      return { artist: parts[0].trim(), title: parts.slice(1).join(" - ").trim() };
    }
    return { artist: "", title: base };
  }

  /* metadata probe queue, kept light */

  const probeQueue = [];
  let probeActive = 0;

  function probeTrack(track) {
    probeQueue.push(track);
    pumpProbe();
  }

  function pumpProbe() {
    while (probeActive < 3 && probeQueue.length) {
      const track = probeQueue.shift();
      probeActive++;
      const el = document.createElement(track.isVideo ? "video" : "audio");
      el.preload = "metadata";
      let done = false;
      const finish = (dur) => {
        if (done) return;
        done = true;
        if (track.duration === null) track.duration = dur;
        try { el.removeAttribute("src"); el.load(); } catch (_) {}
        probeActive--;
        renderPlaylist();
        renderTotals();
        pumpProbe();
      };
      el.addEventListener("loadedmetadata", () => {
        const d = isFinite(el.duration) ? el.duration : 0;
        finish(d);
      }, { once: true });
      el.addEventListener("error", () => finish(0), { once: true });
      el.src = track.url;
      // safety net for stuck probes
      setTimeout(() => finish(track.duration || 0), 12000);
    }
  }

  /* ---------------- playlist ---------------- */

  function addFiles(fileList, opts = {}) {
    const files = Array.from(fileList || []).filter(isMediaFile);
    if (!files.length) {
      if (!opts.silent) setStatus("No supported media in that selection");
      return;
    }

    const wasIdle = state.current < 0;
    const firstNew = state.tracks.length;

    for (const f of files) {
      const { artist, title } = parseName(f.name);
      const track = {
        id: "t" + ++seq,
        name: f.name,
        title: title || f.name,
        artist,
        url: URL.createObjectURL(f),
        duration: null,
        isVideo: (f.type && f.type.startsWith("video/")) || VIDEO_RE.test(f.name),
      };
      state.tracks.push(track);
      probeTrack(track);
    }

    renderPlaylist();
    renderTotals();

    if (wasIdle) {
      playIndex(firstNew);
    } else if (opts.playNow) {
      playIndex(firstNew);
    } else {
      setStatus(`Added ${files.length} item${files.length === 1 ? "" : "s"}`);
    }
  }

  function selectTrack(i) {
    if (i < 0 || i >= state.tracks.length) return;
    state.current = i;
    renderPlaylist();
    updateNowPlaying();
  }

  function playIndex(i) {
    if (i < 0 || i >= state.tracks.length) return;
    const track = state.tracks[i];
    state.current = i;

    ensureAudio();
    els.media.src = track.url;
    els.media.load();
    els.media.play().catch(() => {});

    renderPlaylist();
    updateNowPlaying();
    scrollActiveIntoView();
  }

  function togglePlay() {
    if (!state.tracks.length) {
      els.fileInput.click();
      return;
    }
    if (state.current < 0) {
      playIndex(0);
      return;
    }
    if (els.media.paused) {
      if (!els.media.currentSrc && state.current >= 0) {
        playIndex(state.current);
        return;
      }
      ensureAudio();
      els.media.play().catch(() => {});
    } else {
      els.media.pause();
    }
  }

  function stopPlayback() {
    els.media.pause();
    els.media.removeAttribute("src");
    try { els.media.load(); } catch (_) {}
    state.playing = false;
    updateTransport();
    setStatus("Stopped");
  }

  function nextTrack(userInitiated = false) {
    if (!state.tracks.length) return;
    if (state.current < 0) {
      playIndex(0);
      return;
    }
    if (state.current + 1 < state.tracks.length) {
      playIndex(state.current + 1);
    } else if (userInitiated) {
      playIndex(0);
    } else {
      stopPlayback();
      setStatus("Ready");
    }
  }

  function prevTrack() {
    if (!state.tracks.length) return;
    if (els.media.currentTime > 3) {
      els.media.currentTime = 0;
      return;
    }
    if (state.current > 0) playIndex(state.current - 1);
    else playIndex(state.tracks.length - 1);
  }

  function removeTrack(id) {
    const idx = state.tracks.findIndex((t) => t.id === id);
    if (idx < 0) return;
    const track = state.tracks[idx];
    URL.revokeObjectURL(track.url);
    state.tracks.splice(idx, 1);

    if (idx === state.current) {
      stopPlayback();
      state.current = -1;
      updateNowPlaying();
      els.media.removeAttribute("src");
    } else if (idx < state.current) {
      state.current--;
    }

    renderPlaylist();
    renderTotals();
  }

  function clearPlaylist() {
    state.tracks.forEach((t) => URL.revokeObjectURL(t.url));
    state.tracks = [];
    state.current = -1;
    stopPlayback();
    els.media.removeAttribute("src");
    updateNowPlaying();
    renderPlaylist();
    renderTotals();
    setStatus("Ready");
  }

  /* ---------------- rendering ---------------- */

  function renderPlaylist() {
    els.playlist.textContent = "";
    state.tracks.forEach((track, i) => {
      const li = document.createElement("li");
      li.className = "pl-item" + (i === state.current ? " active" : "");
      li.dataset.id = track.id;
      li.dataset.index = String(i);

      const title = document.createElement("span");
      title.className = "pl-title";
      if (i === state.current) {
        const mark = document.createElementNS("http://www.w3.org/2000/svg", "svg");
        mark.setAttribute("viewBox", "0 0 10 10");
        mark.setAttribute("class", "pl-playmark");
        const p = document.createElementNS("http://www.w3.org/2000/svg", "path");
        p.setAttribute("d", "M2 1.2l6.4 3.8L2 8.8z");
        p.setAttribute("fill", "currentColor");
        mark.append(p);
        title.append(mark);
      }
      const titleText = document.createElement("span");
      titleText.className = "pl-title-text";
      titleText.textContent = track.title;
      title.append(titleText);

      const artist = document.createElement("span");
      artist.className = "pl-artist";
      artist.textContent = track.artist || "—";

      const dur = document.createElement("span");
      dur.className = "pl-dur";
      dur.textContent = track.duration ? fmtTime(track.duration) : "--:--";

      li.append(title, artist, dur);
      els.playlist.append(li);
    });

    els.plEmpty.classList.toggle("hidden", state.tracks.length > 0);
    els.playlist.classList.toggle("hidden", state.tracks.length === 0);
    $("btn-prev").disabled = state.tracks.length === 0;
    $("btn-next").disabled = state.tracks.length === 0;
  }

  function renderTotals() {
    const total = state.tracks.reduce((sum, t) => sum + (t.duration || 0), 0);
    els.totalTime.textContent = fmtTime(total);
  }

  function updateNowPlaying() {
    const track = state.tracks[state.current];
    els.trackTitle.textContent = track ? track.title : "Nostalgia Player";
    els.trackSub.textContent = track
      ? track.artist || track.name
      : "Drag music or video files here";
    els.statusExt.textContent = track ? extOf(track.name) : "";
  }

  function extOf(name) {
    const m = /\.([^.]+)$/.exec(name);
    return m ? m[1].toUpperCase() : "";
  }

  function updateTransport() {
    els.btnPlay.querySelector(".ic-play").classList.toggle("hidden", state.playing);
    els.btnPlay.querySelector(".ic-pause").classList.toggle("hidden", !state.playing);
    els.btnMute.querySelector(".spk-wave").classList.toggle("hidden", state.muted);
    els.btnMute.querySelector(".spk-x").classList.toggle("hidden", !state.muted);
  }

  function setStatus(text) {
    els.statusText.textContent = text;
  }

  function scrollActiveIntoView() {
    const active = els.playlist.querySelector(".pl-item.active");
    if (active) active.scrollIntoView({ block: "nearest" });
  }

  /* ---------------- playback events ---------------- */

  els.media.addEventListener("play", () => {
    state.playing = true;
    updateTransport();
    setStatus("Playing");
    els.stage.classList.toggle("has-video", els.media.videoWidth > 0);
  });

  els.media.addEventListener("pause", () => {
    state.playing = false;
    updateTransport();
    if (state.current >= 0) setStatus("Paused");
  });

  els.media.addEventListener("ended", () => nextTrack(false));

  els.media.addEventListener("loadedmetadata", () => {
    const track = state.tracks[state.current];
    if (track && track.duration === null && isFinite(els.media.duration)) {
      track.duration = els.media.duration;
      renderPlaylist();
      renderTotals();
    }
    els.stage.classList.toggle("has-video", els.media.videoWidth > 0);
    setStatus(els.media.paused ? "Paused" : "Playing");
  });

  els.media.addEventListener("error", () => {
    if (state.current >= 0) setStatus("Cannot play this file");
  });

  els.media.addEventListener("timeupdate", () => {
    if (draggingSeek) return;
    updateProgress();
  });

  els.media.addEventListener("volumechange", () => {
    state.muted = els.media.muted;
    updateTransport();
  });

  function updateProgress() {
    const dur = isFinite(els.media.duration) ? els.media.duration : 0;
    const cur = els.media.currentTime || 0;
    const frac = dur > 0 ? cur / dur : 0;

    els.timeCur.textContent = fmtTime(cur);
    els.timeDur.textContent = fmtTime(dur);
    els.seekFill.style.width = `calc(${(frac * 100).toFixed(3)}% - ${frac > 0 ? 2 : 0}px)`;
    els.seekThumb.style.left = `${(frac * 100).toFixed(3)}%`;
    els.seekbar.setAttribute("aria-valuenow", String(Math.round(frac * 100)));
  }

  /* ---------------- sliders ---------------- */

  let draggingSeek = false;

  function bindSlider(el, onValue) {
    const move = (clientX) => {
      const r = el.getBoundingClientRect();
      const frac = clamp((clientX - r.left) / r.width, 0, 1);
      onValue(frac);
    };

    el.addEventListener("pointerdown", (e) => {
      if (e.button !== 0) return;
      e.preventDefault();
      el.setPointerCapture(e.pointerId);
      onValue.start && onValue.start();
      move(e.clientX);
    });
    el.addEventListener("pointermove", (e) => {
      if (!el.hasPointerCapture(e.pointerId)) return;
      move(e.clientX);
    });
    const end = (e) => {
      if (el.hasPointerCapture(e.pointerId)) el.releasePointerCapture(e.pointerId);
      onValue.end && onValue.end();
    };
    el.addEventListener("pointerup", end);
    el.addEventListener("pointercancel", end);
  }

  const seekHandler = (frac) => {
    const dur = isFinite(els.media.duration) ? els.media.duration : 0;
    if (dur > 0) els.media.currentTime = frac * dur;
    els.seekFill.style.width = `calc(${(frac * 100).toFixed(3)}% - ${frac > 0 ? 2 : 0}px)`;
    els.seekThumb.style.left = `${(frac * 100).toFixed(3)}%`;
    els.timeCur.textContent = fmtTime(frac * dur);
  };
  seekHandler.start = () => { draggingSeek = true; };
  seekHandler.end = () => { draggingSeek = false; };
  bindSlider(els.seekbar, seekHandler);

  function setVolume(v) {
    state.volume = clamp(v, 0, 1);
    state.muted = false;
    els.media.muted = false;
    els.media.volume = state.volume;
    els.volFill.style.width = `calc(${(state.volume * 100).toFixed(2)}% - ${state.volume > 0 ? 2 : 0}px)`;
    els.volThumb.style.left = `${(state.volume * 100).toFixed(2)}%`;
    updateTransport();
  }
  bindSlider(els.volbar, setVolume);

  els.btnMute.addEventListener("click", () => {
    state.muted = !state.muted;
    els.media.muted = state.muted;
    updateTransport();
  });

  /* ---------------- transport buttons ---------------- */

  els.btnPlay.addEventListener("click", togglePlay);
  $("btn-stop").addEventListener("click", stopPlayback);
  $("btn-next").addEventListener("click", () => nextTrack(true));
  $("btn-prev").addEventListener("click", prevTrack);
  els.btnPlAdd.addEventListener("click", () => els.fileInput.click());
  els.btnPlClear.addEventListener("click", clearPlaylist);

  /* ---------------- playlist clicks ---------------- */

  els.playlist.addEventListener("click", (e) => {
    const li = e.target.closest(".pl-item");
    if (!li) return;
    playIndex(Number(li.dataset.index));
  });

  els.playlist.addEventListener("contextmenu", (e) => {
    const li = e.target.closest(".pl-item");
    if (!li) return;
    e.preventDefault();
    removeTrack(li.dataset.id);
  });

  /* ---------------- visualisations ---------------- */

  const peaks = new Array(96).fill(0);
  let vizSize = { w: 1, h: 1 };
  let miniSize = { w: 1, h: 1 };

  function fitCanvas(canvas) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const r = canvas.getBoundingClientRect();
    const w = Math.max(1, Math.round(r.width * dpr));
    const h = Math.max(1, Math.round(r.height * dpr));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }
    const g = canvas.getContext("2d");
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { g, w: r.width, h: r.height };
  }

  function resizeAll() {
    const r = els.viz.getBoundingClientRect();
    vizSize = { w: r.width, h: r.height };
    const m = els.miniViz.getBoundingClientRect();
    miniSize = { w: m.width, h: m.height };
  }

  if (window.ResizeObserver) {
    const ro = new ResizeObserver(() => resizeAll());
    ro.observe(els.viz);
    ro.observe(els.miniViz);
  }
  window.addEventListener("resize", resizeAll);

  function idleSpectrum(dest, t) {
    const n = dest.length;
    for (let i = 0; i < n; i++) {
      const x = i / n;
      const tilt = 1.2 - 0.55 * x; // bass-heavy, like real music
      const v =
        (105 +
          58 * Math.sin(t * 1.6 + x * 8) +
          32 * Math.sin(t * 0.9 + x * 21 + 1.3) +
          18 * Math.sin(t * 3.2 + x * 37) +
          12 * Math.sin(t * 5.1 + x * 97)) * tilt;
      dest[i] = clamp(v, 0, 255);
    }
  }

  function idleWave(dest, t) {
    const n = dest.length;
    for (let i = 0; i < n; i++) {
      const x = i / n;
      dest[i] = 128 + 48 * Math.sin(x * 28 + t * 2.1) * Math.sin(x * Math.PI) + 12 * Math.sin(x * 70 - t * 3.4);
    }
  }

  function bucket(data, i, n, tilt = 1.7) {
    const len = data.length;
    const lo = Math.floor(Math.pow(i / n, tilt) * len * 0.72);
    const hi = Math.max(lo + 1, Math.floor(Math.pow((i + 1) / n, tilt) * len * 0.72));
    let sum = 0;
    let count = 0;
    for (let j = lo; j < hi && j < len; j++) {
      sum += data[j];
      count++;
    }
    return count ? sum / count : 0;
  }

  function bgFill(g, w, h) {
    // WMP 8 full mode uses a black presentation surface (R1/R2 in the map).
    // Custom visualization palettes stay unchanged until a verified reference exists.
    g.fillStyle = "#000";
    g.fillRect(0, 0, w, h);
  }

  function drawBars(g, w, h, data, t) {
    bgFill(g, w, h);
    const n = 64;
    const step = w / n;
    const bw = Math.max(2, step * 0.58);
    const base = h * 0.74;
    const maxH = h * 0.5;

    g.save();
    g.beginPath();
    g.rect(0, 0, w, base);
    g.clip();

    for (let i = 0; i < n; i++) {
      const v = bucket(data, i, n) / 255;
      const bh = Math.max(2, (0.04 + 0.96 * Math.pow(v, 1.55)) * maxH + Math.abs(Math.sin(t * 2 + i * 0.3)) * 1.6);
      peaks[i] = Math.max(peaks[i] * 0.965, bh);

      const x = i * step + (step - bw) / 2;
      const y = base - bh;

      const grad = g.createLinearGradient(0, base, 0, base - maxH);
      grad.addColorStop(0, "rgba(28,88,255,0.95)");
      grad.addColorStop(0.5, "rgba(0,190,255,0.95)");
      grad.addColorStop(1, "rgba(190,250,255,1)");

      g.shadowColor = "rgba(0,180,255,0.55)";
      g.shadowBlur = 9;
      g.fillStyle = grad;
      g.fillRect(x, y, bw, bh);
      g.shadowBlur = 0;

      if (peaks[i] > bh + 2) {
        g.fillStyle = "rgba(255,240,170,0.85)";
        g.fillRect(x, base - peaks[i] - 2, bw, 2);
      }
    }

    // reflection
    g.globalAlpha = 0.16;
    g.translate(0, base * 2);
    g.scale(1, -1);
    for (let i = 0; i < n; i++) {
      const v = bucket(data, i, n) / 255;
      const bh = Math.max(2, (0.04 + 0.96 * Math.pow(v, 1.55)) * maxH);
      const x = i * step + (step - bw) / 2;
      const grad = g.createLinearGradient(0, base, 0, base - maxH);
      grad.addColorStop(0, "rgba(30,110,255,0.9)");
      grad.addColorStop(1, "rgba(120,230,255,0.1)");
      g.fillStyle = grad;
      g.fillRect(x, base - bh, bw, bh);
    }
    g.restore();

    // baseline
    g.fillStyle = "rgba(120,190,255,0.28)";
    g.fillRect(0, base, w, 1);
  }

  function drawWaves(g, w, h, wave, t) {
    bgFill(g, w, h);

    g.save();
    g.strokeStyle = "rgba(80,150,255,0.10)";
    g.lineWidth = 1;
    for (let y = 1; y < 6; y++) {
      g.beginPath();
      g.moveTo(0, (h / 6) * y);
      g.lineTo(w, (h / 6) * y);
      g.stroke();
    }
    for (let x = 1; x < 10; x++) {
      g.beginPath();
      g.moveTo((w / 10) * x, 0);
      g.lineTo((w / 10) * x, h);
      g.stroke();
    }
    g.restore();

    const colors = [
      ["rgba(0,230,255,0.95)", "rgba(0,230,255,0.15)"],
      ["rgba(70,130,255,0.75)", "rgba(70,130,255,0.1)"],
      ["rgba(190,245,255,0.6)", "rgba(190,245,255,0.06)"],
    ];

    for (let k = 0; k < 3; k++) {
      g.save();
      g.strokeStyle = colors[k][0];
      g.shadowColor = colors[k][0];
      g.shadowBlur = 14 - k * 4;
      g.lineWidth = 1.7 - k * 0.35;
      g.beginPath();
      const amp = (h * 0.30) / (1 + k * 0.8);
      for (let i = 0; i < wave.length; i += 2) {
        const x = (i / (wave.length - 1)) * w;
        const v = (wave[i] - 128) / 128;
        const y = h * 0.5 + v * amp + Math.sin(t * 0.8 + k) * 4;
        if (i === 0) g.moveTo(x, y);
        else g.lineTo(x, y);
      }
      g.stroke();
      g.restore();
    }
  }

  const particles = Array.from({ length: 64 }, (_, i) => ({
    a: (i / 64) * Math.PI * 2,
    r: 0.35 + Math.random() * 0.6,
    s: 0.1 + Math.random() * 0.5,
    z: 0.4 + Math.random() * 1.4,
  }));

  function drawAmbience(g, w, h, data, t) {
    g.fillStyle = "#03060e";
    g.fillRect(0, 0, w, h);

    const cx = w / 2;
    const cy = h * 0.52;
    const R = Math.min(w, h) * 0.19;
    const bass = bucket(data, 2, 64) / 255;

    g.save();
    g.globalCompositeOperation = "lighter";

    const glow = g.createRadialGradient(cx, cy, R * 0.2, cx, cy, R * (2.6 + bass * 0.9));
    glow.addColorStop(0, `rgba(40,120,255,${0.24 + bass * 0.25})`);
    glow.addColorStop(0.45, "rgba(20,60,160,0.16)");
    glow.addColorStop(1, "rgba(0,0,0,0)");
    g.fillStyle = glow;
    g.fillRect(0, 0, w, h);

    const count = 84;
    for (let i = 0; i < count; i++) {
      const v = bucket(data, i, count, 1.5) / 255;
      const a = (i / count) * Math.PI * 2 + t * 0.12;
      const len = R * (0.35 + v * 1.5);
      const r0 = R * 0.78;
      const x1 = cx + Math.cos(a) * r0;
      const y1 = cy + Math.sin(a) * r0;
      const x2 = cx + Math.cos(a) * (r0 + len);
      const y2 = cy + Math.sin(a) * (r0 + len);

      const hue = 205 + v * 70;
      g.strokeStyle = `hsla(${hue}, 100%, ${55 + v * 30}%, ${0.25 + v * 0.65})`;
      g.lineWidth = 1.4 + v * 2.2;
      g.shadowColor = `hsla(${hue}, 100%, 65%, 0.7)`;
      g.shadowBlur = 8;
      g.beginPath();
      g.moveTo(x1, y1);
      g.lineTo(x2, y2);
      g.stroke();
    }

    g.shadowBlur = 0;

    for (const p of particles) {
      p.a += p.s * 0.004;
      const orbit = Math.min(w, h) * 0.5 * p.r;
      const x = cx + Math.cos(p.a) * orbit;
      const y = cy + Math.sin(p.a) * orbit * 0.72;
      const tw = 0.35 + 0.65 * Math.abs(Math.sin(t * p.z + p.a));
      g.fillStyle = `rgba(150,220,255,${0.10 + tw * 0.45})`;
      g.beginPath();
      g.arc(x, y, 0.8 + tw * 1.6, 0, Math.PI * 2);
      g.fill();
    }

    const ring = g.createRadialGradient(cx, cy, 1, cx, cy, R);
    ring.addColorStop(0, "rgba(120,210,255,0.85)");
    ring.addColorStop(0.7, "rgba(20,90,220,0.25)");
    ring.addColorStop(1, "rgba(0,0,0,0)");
    g.fillStyle = ring;
    g.beginPath();
    g.arc(cx, cy, R * (1 + bass * 0.18), 0, Math.PI * 2);
    g.fill();

    g.restore();
  }

  function currentFreq(t) {
    if (analyser && state.playing) {
      analyser.getByteFrequencyData(freqData);
      return freqData;
    }
    idleSpectrum(freqData, t);
    return freqData;
  }

  function currentWave(t) {
    if (analyser && state.playing) {
      analyser.getByteTimeDomainData(waveData);
      return waveData;
    }
    idleWave(waveData, t);
    return waveData;
  }

  function drawMini(g, w, h, data, t) {
    g.clearRect(0, 0, w, h);
    const n = 42;
    const step = w / n;
    const bw = Math.max(1.5, step * 0.6);
    for (let i = 0; i < n; i++) {
      const v = bucket(data, i, n, 1.6) / 255;
      const bh = Math.max(1, (0.05 + 0.95 * Math.pow(v, 1.5)) * (h - 3) + Math.abs(Math.sin(t * 2.4 + i * 0.4)) * 1.1);
      const grad = g.createLinearGradient(0, h, 0, 0);
      grad.addColorStop(0, "rgba(30,110,255,0.9)");
      grad.addColorStop(0.55, "rgba(0,210,255,0.95)");
      grad.addColorStop(1, "rgba(210,250,255,0.95)");
      g.fillStyle = grad;
      g.shadowColor = "rgba(0,200,255,0.45)";
      g.shadowBlur = 4;
      g.fillRect(i * step + (step - bw) / 2, h - bh, bw, bh);
    }
    g.shadowBlur = 0;
  }

  function frame(now) {
    const t = now / 1000;

    const viz = fitCanvas(els.viz);
    if (!els.stage.classList.contains("has-video")) {
      if (state.mode === 0) drawBars(viz.g, viz.w, viz.h, currentFreq(t), t);
      else if (state.mode === 1) drawWaves(viz.g, viz.w, viz.h, currentWave(t), t);
      else drawAmbience(viz.g, viz.w, viz.h, currentFreq(t), t);
    }

    const mini = fitCanvas(els.miniViz);
    drawMini(mini.g, mini.w, mini.h, currentFreq(t), t);

    if (state.playing && !draggingSeek) updateProgress();

    requestAnimationFrame(frame);
  }

  function setMode(i) {
    state.mode = (i + MODES.length) % MODES.length;
    els.vizName.textContent = MODES[state.mode];
  }

  $("viz-prev").addEventListener("click", () => setMode(state.mode - 1));
  $("viz-next").addEventListener("click", () => setMode(state.mode + 1));

  /* ---------------- menus ---------------- */

  function closeMenus(restoreFocus = false) {
    const open = document.querySelector(".menu.open");
    $$(".menu").forEach((m) => {
      m.classList.remove("open");
      m.querySelector(".menu-label").setAttribute("aria-expanded", "false");
    });
    if (restoreFocus && open) open.querySelector(".menu-label").focus();
  }

  function openMenu(menu, focusItem = false, lastItem = false) {
    closeMenus();
    menu.classList.add("open");
    menu.querySelector(".menu-label").setAttribute("aria-expanded", "true");
    if (focusItem) {
      const items = $$(".menu-pop button", menu);
      items[lastItem ? items.length - 1 : 0].focus();
    }
  }

  $$(".menu").forEach((menu) => {
    const label = menu.querySelector(".menu-label");
    $$(".menu-pop button", menu).forEach((item) => {
      item.setAttribute("role", "menuitem");
      item.tabIndex = -1;
    });
    label.addEventListener("mousedown", (e) => {
      if (e.button !== 0) return;
      e.stopPropagation();
      const wasOpen = menu.classList.contains("open");
      closeMenus();
      if (!wasOpen) openMenu(menu);
    });
    menu.addEventListener("mouseenter", () => {
      if (document.querySelector(".menu.open") && !menu.classList.contains("open")) openMenu(menu);
    });
    menu.addEventListener("keydown", (e) => {
      const items = $$(".menu-pop button", menu);
      const index = items.indexOf(document.activeElement);
      if (e.key === "ArrowDown" || e.key === "ArrowUp" || e.key === "Home" || e.key === "End") {
        e.preventDefault();
        e.stopPropagation();
        if (!menu.classList.contains("open") || index < 0) openMenu(menu, true, e.key === "ArrowUp" || e.key === "End");
        else if (e.key === "Home") items[0].focus();
        else if (e.key === "End") items[items.length - 1].focus();
        else items[(index + (e.key === "ArrowDown" ? 1 : -1) + items.length) % items.length].focus();
      } else if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
        e.preventDefault();
        e.stopPropagation();
        const menus = $$(".menu");
        const next = menus[(menus.indexOf(menu) + (e.key === "ArrowRight" ? 1 : -1) + menus.length) % menus.length];
        const wasOpen = menu.classList.contains("open");
        closeMenus();
        next.querySelector(".menu-label").focus();
        if (wasOpen) openMenu(next, true);
      } else if (e.key === "Escape") {
        e.preventDefault();
        e.stopPropagation();
        closeMenus(true);
      } else if ((e.key === "Enter" || e.key === " ") && e.target === label) {
        e.preventDefault();
        e.stopPropagation();
        openMenu(menu, true);
      } else if (e.key === " " && index >= 0) {
        e.preventDefault();
        e.stopPropagation();
        items[index].click();
      } else if (e.key === "Tab") closeMenus();
    });
  });

  document.addEventListener("mousedown", (e) => {
    if (!e.target.closest(".menu")) closeMenus();
  });

  let aboutReturnFocus = null;

  function openAbout(trigger) {
    const menu = trigger.closest(".menu");
    aboutReturnFocus = menu ? menu.querySelector(".menu-label") : document.activeElement;
    els.about.classList.remove("hidden");
    [els.titlebar, $("menubar"), $("shell")].forEach((el) => { el.inert = true; });
    els.about.querySelector(".xp-button").focus();
  }

  function closeAbout() {
    els.about.classList.add("hidden");
    [els.titlebar, $("menubar"), $("shell")].forEach((el) => { el.inert = false; });
    if (aboutReturnFocus && aboutReturnFocus.isConnected) aboutReturnFocus.focus();
    aboutReturnFocus = null;
  }

  function toggleTheater() {
    state.theater = !state.theater;
    els.app.classList.toggle("theater", state.theater);
    ipc("toggle_fullscreen");
  }

  document.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-action]");
    if (!btn) return;
    closeMenus();

    switch (btn.dataset.action) {
      case "add-files": els.fileInput.click(); break;
      case "add-folder": els.dirInput.click(); break;
      case "clear": clearPlaylist(); break;
      case "exit": ipc("close"); break;
      case "viz-bars": setMode(0); break;
      case "viz-waves": setMode(1); break;
      case "viz-ambience": setMode(2); break;
      case "theater": toggleTheater(); break;
      case "toggle": togglePlay(); break;
      case "stop": stopPlayback(); break;
      case "prev": prevTrack(); break;
      case "next": nextTrack(true); break;
      case "about": openAbout(btn); break;
      case "close-about": closeAbout(); break;
      case "open-folder": els.dirInput.click(); break;
      default: break;
    }
  });

  /* ---------------- file inputs ---------------- */

  els.fileInput.addEventListener("change", () => {
    if (els.fileInput.files && els.fileInput.files.length) {
      addFiles(els.fileInput.files, { playNow: true });
    }
    els.fileInput.value = "";
  });

  els.dirInput.addEventListener("change", () => {
    if (els.dirInput.files && els.dirInput.files.length) {
      addFiles(els.dirInput.files);
    }
    els.dirInput.value = "";
  });

  /* ---------------- drag and drop ---------------- */

  let dragDepth = 0;

  window.addEventListener("dragenter", (e) => {
    e.preventDefault();
    dragDepth++;
    els.stage.classList.add("dragging");
  });
  window.addEventListener("dragover", (e) => {
    e.preventDefault();
    if (e.dataTransfer) e.dataTransfer.dropEffect = "copy";
  });
  window.addEventListener("dragleave", (e) => {
    e.preventDefault();
    dragDepth = Math.max(0, dragDepth - 1);
    if (dragDepth === 0) els.stage.classList.remove("dragging");
  });
  window.addEventListener("drop", (e) => {
    e.preventDefault();
    dragDepth = 0;
    els.stage.classList.remove("dragging");
    if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length) {
      addFiles(e.dataTransfer.files, { playNow: true });
    }
  });

  /* ---------------- window chrome ---------------- */

  $("btn-min").addEventListener("click", () => ipc("minimize"));
  $("btn-max").addEventListener("click", () => ipc("maximize"));
  $("btn-close").addEventListener("click", () => ipc("close"));

  els.titlebar.addEventListener("mousedown", (e) => {
    if (e.button !== 0) return;
    if (e.target.closest("button")) return;
    if (e.detail === 2) ipc("maximize");
    else ipc("drag_window");
  });

  /* ---------------- window edges (main window only) ---------------- */

  const EDGE = 6;
  const CURSORS = {
    n: "ns-resize", s: "ns-resize",
    w: "ew-resize", e: "ew-resize",
    nw: "nwse-resize", se: "nwse-resize",
    ne: "nesw-resize", sw: "nesw-resize",
  };

  function edgeAt(x, y) {
    const w = window.innerWidth;
    const h = window.innerHeight;
    const left = x < EDGE;
    const right = x > w - EDGE;
    const top = y < EDGE;
    const bottom = y > h - EDGE;
    if (top && left) return "nw";
    if (top && right) return "ne";
    if (bottom && left) return "sw";
    if (bottom && right) return "se";
    if (top) return "n";
    if (bottom) return "s";
    if (left) return "w";
    if (right) return "e";
    return null;
  }

  window.addEventListener("mousemove", (e) => {
    const edge = edgeAt(e.clientX, e.clientY);
    document.body.style.cursor = edge ? CURSORS[edge] : "";
  });

  window.addEventListener("mousedown", (e) => {
    if (e.button !== 0) return;
    const edge = edgeAt(e.clientX, e.clientY);
    if (!edge) return;
    e.preventDefault();
    e.stopPropagation();
    ipc("resize:" + edge);
  }, true);

  els.stage.addEventListener("dblclick", (e) => {
    if (e.target === els.media) toggleTheater();
  });

/* ---------------- wheel = volume ---------------- */

  window.addEventListener("wheel", (e) => {
    if (e.target.closest(".playlist")) return;
    e.preventDefault();
    setVolume(state.volume + (e.deltaY < 0 ? 0.05 : -0.05));
  }, { passive: false });

  /* ---------------- keyboard ---------------- */

  window.addEventListener("keydown", (e) => {
    if (!els.about.classList.contains("hidden")) {
      if (e.key === "Escape") {
        e.preventDefault();
        closeAbout();
      } else if (e.key === "Tab") {
        const buttons = $$("button", els.about);
        const first = buttons[0];
        const last = buttons[buttons.length - 1];
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }
      return;
    }
    if (e.target && (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA")) return;

    switch (e.key) {
      case " ":
        e.preventDefault();
        togglePlay();
        break;
      case "ArrowRight":
        e.preventDefault();
        els.media.currentTime = clamp(els.media.currentTime + 5, 0, els.media.duration || 0);
        break;
      case "ArrowLeft":
        e.preventDefault();
        els.media.currentTime = clamp(els.media.currentTime - 5, 0, els.media.duration || 0);
        break;
      case "ArrowUp":
        e.preventDefault();
        setVolume(state.volume + 0.05);
        break;
      case "ArrowDown":
        e.preventDefault();
        setVolume(state.volume - 0.05);
        break;
      case "Escape":
        if (state.theater) toggleTheater();
        closeMenus();
        break;
      case "F11":
        e.preventDefault();
        toggleTheater();
        break;
      default:
        if (e.ctrlKey && (e.key === "o" || e.key === "O")) {
          e.preventDefault();
          els.fileInput.click();
        } else if (e.key === "n" || e.key === "N") {
          nextTrack(true);
        } else if (e.key === "p" || e.key === "P") {
          prevTrack();
        }
        break;
    }
  });

  /* ---------------- clock ---------------- */

  function tickClock() {
    const d = new Date();
    els.clock.textContent = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  }
  tickClock();
  setInterval(tickClock, 1000);

  /* ---------------- boot ---------------- */

  els.media.volume = state.volume;
  setVolume(state.volume);
  setMode(0);
  updateTransport();
  updateNowPlaying();
  renderPlaylist();
  renderTotals();
  setStatus("Ready");
  resizeAll();

  const hashMode = location.hash.replace("#", "").toLowerCase();
  const hashIndex = MODES.findIndex((m) => m.toLowerCase() === hashMode);
  if (hashIndex >= 0) setMode(hashIndex);

  requestAnimationFrame(frame);
})();
