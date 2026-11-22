// Generate a short 16:9 VP8 verification fixture inside the actual WebView2.
// Not part of the UI; returned bytes are saved in docs/testmedia/ by the harness.
(async () => {
  const canvas = document.createElement("canvas");
  canvas.width = 320;
  canvas.height = 180;
  const context = canvas.getContext("2d");
  const stream = canvas.captureStream(12);
  const recorder = new MediaRecorder(stream, { mimeType: "video/webm;codecs=vp8", videoBitsPerSecond: 150000 });
  const chunks = [];
  recorder.ondataavailable = (event) => chunks.push(event.data);
  const finished = new Promise(resolve => { recorder.onstop = resolve; });
  recorder.start();
  await new Promise(resolve => {
    const start = performance.now();
    function draw(now) {
      const colors = ["#c6c6c6", "#d6ca32", "#20baba", "#35b94b", "#bc45b5", "#c03c34", "#3e4fc4"];
      colors.forEach((color, i) => {
        context.fillStyle = color;
        context.fillRect(i * 46, 0, 46, 180);
      });
      context.fillStyle = "#111";
      context.fillRect(12, 50, 296, 80);
      context.fillStyle = "#fff";
      context.font = "bold 20px Tahoma";
      context.textAlign = "center";
      context.fillText("16:9 LOCAL TEST", 160, 84);
      context.font = "13px Tahoma";
      context.fillText("WebM / VP8 - generated fixture", 160, 108);
      context.fillStyle = "#fff";
      context.fillRect(((now - start) / 10) % 300, 150, 20, 8);
      if (now - start >= 2400) resolve(); else requestAnimationFrame(draw);
    }
    requestAnimationFrame(draw);
  });
  recorder.stop();
  await finished;
  stream.getTracks().forEach(track => track.stop());
  const bytes = new Uint8Array(await new Blob(chunks).arrayBuffer());
  let binary = "";
  bytes.forEach(byte => { binary += String.fromCharCode(byte); });
  return btoa(binary);
})();
