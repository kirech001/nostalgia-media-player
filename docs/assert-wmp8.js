// Rendered presentation checks, run via CDP against the embedded release UI.
(() => {
  const css = (s) => getComputedStyle(document.querySelector(s));
  const results = [];
  const check = (step, name, pass) => results.push({ step, name, pass: !!pass });
  check("C1", "XP beige menubar", css(".menubar").backgroundColor === "rgb(236, 233, 216)");
  check("C1", "13px compact caption", css(".title-text").fontSize === "13px" && css(".title-text").letterSpacing === "normal");
  check("C2", "black playlist surface", css(".pl-list").backgroundColor === "rgb(0, 0, 0)");
  check("C2", "matching playlist column grid", css(".pl-cols").gridTemplateColumns === (document.querySelector(".pl-item") ? css(".pl-item").gridTemplateColumns : css(".pl-cols").gridTemplateColumns));
  check("C3", "black stage surface", css(".stage-bg").backgroundColor === "rgb(0, 0, 0)" && css(".stage-bg").backgroundImage === "none");
  check("C3", "metadata at top", css(".stage-overlay").top === "0px" && css(".track-title").fontWeight === "400");
  check("C3", "visualization controls have no glass", css(".stage-tools").backdropFilter === "none" && css(".stage-tools").left === "8px");
  check("C4", "24px slider hit boxes", css(".seekbar").height === "24px" && css(".volbar").height === "24px");
  check("C4", "empty prev/next disabled; populated enabled", ["btn-prev", "btn-next"].every(id => document.getElementById(id).disabled === (document.querySelectorAll(".pl-item").length === 0)));
  check("C5", "empty extension segment omitted", document.getElementById("status-ext").textContent.length > 0 || css("#status-ext").display === "none");
  check("C6", "native menu trigger buttons", [...document.querySelectorAll(".menu-label")].every(e => e.tagName === "BUTTON" && e.getAttribute("aria-haspopup") === "menu"));
  check("C6", "About named modal dialog", document.querySelector(".dialog").getAttribute("role") === "dialog" && document.querySelector(".dialog").getAttribute("aria-modal") === "true" && !!document.querySelector(".dialog").getAttribute("aria-labelledby"));
  check("ALL", "no horizontal page overflow", document.documentElement.scrollWidth === innerWidth);
  check("ALL", "letterboxing retained", css("#media").objectFit === "contain");
  return results;
})();
