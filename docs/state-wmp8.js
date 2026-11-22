(() => ({
  width: innerWidth, height: innerHeight, dpr: devicePixelRatio,
  screen: {width:screen.width,height:screen.height,availWidth:screen.availWidth,availHeight:screen.availHeight},
  theater: document.getElementById("app").classList.contains("theater"),
  mode: document.getElementById("viz-name").textContent,
  status: document.getElementById("status-text").textContent,
  time: document.getElementById("media").currentTime,
  paused: document.getElementById("media").paused,
  ready: document.getElementById("media").readyState,
  active: document.querySelector(".pl-item.active")?.dataset.index,
  open: document.querySelector(".menu.open")?.dataset.menu,
}))();
