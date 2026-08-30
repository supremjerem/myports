import { ApiError, MyPortsClient } from "./api";
import type { PortDTO, PortsResponse } from "./types";

const TOKEN_KEY = "myports.token";
const app = document.getElementById("app") as HTMLElement;

let client: MyPortsClient | null = null;
let dispose: (() => void) | null = null;

function base(): string {
  return window.location.origin;
}

function saveToken(token: string): void {
  try {
    localStorage.setItem(TOKEN_KEY, token);
  } catch {
    /* private mode — session only */
  }
}

function loadToken(): string {
  try {
    return localStorage.getItem(TOKEN_KEY) ?? "";
  } catch {
    return "";
  }
}

function render(state: {
  ports?: PortsResponse;
  error?: string;
  needsToken?: boolean;
  status?: string;
}): void {
  app.innerHTML = "";

  const header = el("header", "");
  header.append(el("h1", "MyPorts"));
  if (state.status) header.append(el("span", state.status, "status"));
  app.append(header);

  if (state.needsToken) {
    const form = document.createElement("form");
    form.className = "token-form";
    form.innerHTML = `
      <p>Paste a bearer token (create one with <code>portsd token add</code> or the macOS app).</p>
      <input type="password" name="token" placeholder="Bearer token" autocomplete="off" />
      <button type="submit">Connect</button>`;
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      const value = (form.elements.namedItem("token") as HTMLInputElement).value.trim();
      if (value) {
        saveToken(value);
        connect(value);
      }
    });
    app.append(form);
  }

  if (state.error) app.append(el("div", state.error, "error"));

  if (state.ports) {
    if (state.ports.ports.length === 0) {
      app.append(el("div", "No listening TCP ports.", "empty"));
    }
    const list = document.createElement("ul");
    list.className = "ports";
    for (const port of [...state.ports.ports].sort((a, b) => a.port - b.port)) {
      list.append(portRow(port));
    }
    app.append(list);
  }
}

function portRow(port: PortDTO): HTMLElement {
  const li = document.createElement("li");
  li.innerHTML = `
    <div class="port">${port.port}</div>
    <div class="meta">
      <div class="name">${escapeHtml(port.friendlyName)}</div>
      <div class="sub">PID ${port.pid} · ${port.isLoopback ? "loopback" : escapeHtml(port.host)}
        ${port.connectionCount ? ` · ${port.connectionCount} conn` : ""}</div>
    </div>`;
  const kill = document.createElement("button");
  kill.textContent = "Kill";
  kill.className = "kill";
  kill.addEventListener("click", async () => {
    kill.disabled = true;
    kill.textContent = "…";
    try {
      await client?.killPort(port.port, "TERM");
    } catch (error) {
      kill.textContent = error instanceof ApiError ? `${error.status}` : "err";
      return;
    }
    kill.textContent = "✓";
  });
  li.append(kill);
  return li;
}

async function connect(token: string): Promise<void> {
  dispose?.();
  client = new MyPortsClient(base(), token);
  render({ status: "connecting…" });
  try {
    const ports = await client.listPorts();
    render({ ports, status: "live" });
    dispose = client.streamPorts(
      (snapshot) => render({ ports: snapshot, status: "live" }),
      () => render({ ports, status: "reconnecting…" }),
    );
  } catch (error) {
    if (error instanceof ApiError && (error.status === 401 || error.status === 403)) {
      render({ needsToken: true, error: "That token was rejected." });
    } else {
      render({ needsToken: true, error: `Could not reach the agent (${String(error)}).` });
    }
  }
}

const existing = loadToken();
if (existing) {
  void connect(existing);
} else {
  render({ needsToken: true });
}

// helpers

function el(tag: string, text: string, className = ""): HTMLElement {
  const node = document.createElement(tag);
  node.textContent = text;
  if (className) node.className = className;
  return node;
}

function escapeHtml(value: string): string {
  return value.replace(
    /[&<>"']/g,
    (char) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char] as string,
  );
}
