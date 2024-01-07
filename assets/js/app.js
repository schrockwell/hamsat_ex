// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import "../vendor/leaflet-great-circle";
import LeafletPicker from "./leaflet-picker-hook";
import LeafletTracker from "./leaflet-tracker-hook";
import Registration from "./registration-hook";
import CopyToClipboard from "./copy-to-clipboard-hook";

const Hooks = {
  LeafletPicker,
  LeafletTracker,
  Registration,
  CopyToClipboard,
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (info) => topbar.show());
window.addEventListener("phx:page-loading-stop", (info) => topbar.hide());

window.addEventListener("DOMContentLoaded", (event) => {
  // data-toggle="some-other-id"
  document.querySelectorAll("[data-toggle]").forEach((el) => {
    const targetEl = document.querySelector("#" + el.dataset.toggle);
    el.addEventListener("click", () => {
      if (targetEl.classList.contains("hidden")) {
        targetEl.classList.remove("hidden");
      } else {
        targetEl.classList.add("hidden");
      }
    });
  });

  // data-value-of-range="id"
  document.querySelectorAll("[data-value-of-range]").forEach((el) => {
    const rangeEl = document.querySelector("#" + el.dataset.valueOfRange);
    rangeEl.addEventListener("input", () => {
      el.innerHTML = rangeEl.value;
    });
    el.innerHTML = rangeEl.value;
  });
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
