import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

import { csrfToken } from "./csrf";

export const liveSocket = new LiveSocket("/live", Socket, {
  loaderTimeout: 2500,
  params: { _csrf_token: csrfToken },
});

export const initLiveSocket = () => {
  liveSocket.connect();
  window.liveSocket = liveSocket;
};
