/* Post page interactions: submit comments and reactions via the JSON API. */
(function () {
  "use strict";

  var meta = document.querySelector('meta[name="csrf-token"]');
  var csrfToken = meta ? meta.content : "";

  function api(url, payload) {
    return fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify(payload),
    }).then(function (response) {
      return response.json().then(function (data) {
        return { status: response.status, data: data };
      });
    });
  }

  function showError(message) {
    var box = document.getElementById("comment-error");
    if (box) {
      box.textContent = message;
      box.hidden = false;
    }
  }

  function handleAuthOrError(result) {
    if (result.status === 401) {
      window.location.href = "/login?next=" + encodeURIComponent(window.location.pathname);
      return true;
    }
    if (!result.data.ok) {
      showError(result.data.error || "Something went wrong — please try again.");
      return true;
    }
    return false;
  }

  function setUpCommentForm() {
    var form = document.getElementById("comment-form");
    if (!form) return;
    form.addEventListener("submit", function (event) {
      event.preventDefault();
      var field = document.getElementById("comment-body");
      var body = field.value.trim();
      if (!body) {
        showError("Comment cannot be empty.");
        return;
      }
      api(form.dataset.url, { body: body })
        .then(function (result) {
          if (handleAuthOrError(result)) return;
          window.location.reload();
        })
        .catch(function () {
          showError("Network error — please try again.");
        });
    });
  }

  function setUpReactions() {
    var box = document.querySelector(".reactions");
    if (!box) return;
    box.querySelectorAll("[data-react]").forEach(function (button) {
      button.addEventListener("click", function () {
        api(box.dataset.url, { kind: button.dataset.react })
          .then(function (result) {
            if (handleAuthOrError(result)) return;
            updateReactions(box, result.data);
          })
          .catch(function () {
            showError("Network error — please try again.");
          });
      });
    });
  }

  function updateReactions(box, data) {
    box.querySelectorAll("[data-react]").forEach(function (button) {
      var kind = button.dataset.react;
      var count = button.querySelector("[data-count]");
      if (count) count.textContent = data.counts[kind];
      button.classList.toggle("active", data.reaction === kind);
    });
  }

  function setUpConfirms() {
    // CSP blocks inline onsubmit handlers, so confirmation lives here.
    document.querySelectorAll("form[data-confirm]").forEach(function (form) {
      form.addEventListener("submit", function (event) {
        if (!window.confirm(form.dataset.confirm)) event.preventDefault();
      });
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    setUpCommentForm();
    setUpReactions();
    setUpConfirms();
  });
})();
