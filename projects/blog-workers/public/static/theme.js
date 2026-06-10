/* Light/dark theme: applied before first paint, remembered in localStorage. */
(function () {
  "use strict";

  function storedTheme() {
    try {
      return localStorage.getItem("theme");
    } catch (err) {
      return null; // localStorage can be blocked (private mode) — just don't remember
    }
  }

  function preferredTheme() {
    var stored = storedTheme();
    if (stored === "light" || stored === "dark") return stored;
    var prefersDark = window.matchMedia &&
      window.matchMedia("(prefers-color-scheme: dark)").matches;
    return prefersDark ? "dark" : "light";
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme);
    var button = document.getElementById("theme-toggle");
    if (button) {
      button.textContent = theme === "dark" ? "☀️" : "🌙";
      button.setAttribute("aria-label",
        theme === "dark" ? "Switch to light theme" : "Switch to dark theme");
    }
  }

  // Run immediately (script loads in <head>) so the page never flashes.
  applyTheme(preferredTheme());

  document.addEventListener("DOMContentLoaded", function () {
    applyTheme(preferredTheme()); // now the button exists — set its icon
    var button = document.getElementById("theme-toggle");
    if (!button) return;
    button.addEventListener("click", function () {
      var current = document.documentElement.getAttribute("data-theme");
      var next = current === "dark" ? "light" : "dark";
      try {
        localStorage.setItem("theme", next);
      } catch (err) { /* not remembered, but still toggles */ }
      applyTheme(next);
    });
  });
})();
