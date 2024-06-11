import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

import topbar from "topbar";

import { getCSRFToken } from "./lib/csrf";

const csrfToken = getCSRFToken();

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });

window.addEventListener("phx:page-loading-start", () => topbar.show(300));
window.addEventListener("phx:page-loading-stop", () => topbar.hide());

liveSocket.connect();

window.LiveSocket = liveSocket;
