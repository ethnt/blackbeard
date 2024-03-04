import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

import { getCSRFToken } from "./csrf";

export class PhoenixLiveSocket {
  csrfToken: string | null;
  liveSocket: LiveSocket;

  constructor() {
    this.csrfToken = getCSRFToken();
    this.liveSocket = new LiveSocket("/live", Socket, {
      loaderTimeout: 2500,
      params: { _csrf_token: this.csrfToken },
    });
  }

  initialize() {
    this.liveSocket.connect();

    window.LiveSocket = this.liveSocket;
  }
}
