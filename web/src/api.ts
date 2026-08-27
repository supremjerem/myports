import type { DeviceResponse, KillSignal, PortsResponse } from "./types";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

/** Builds `${base}/api/v1/${path}`, tolerating a trailing slash on the base. */
export function apiUrl(base: string, path: string): string {
  return `${base.replace(/\/+$/, "")}/api/v1/${path.replace(/^\/+/, "")}`;
}

/** Parses one SSE `data:` payload into a PortsResponse, or null if it is a comment/garbage. */
export function parsePortsEvent(data: string): PortsResponse | null {
  const trimmed = data.trim();
  if (trimmed === "" || trimmed.startsWith(":")) return null;
  try {
    const parsed = JSON.parse(trimmed) as PortsResponse;
    return Array.isArray(parsed.ports) ? parsed : null;
  } catch {
    return null;
  }
}

export class MyPortsClient {
  constructor(
    private base: string,
    private token: string,
  ) {}

  private headers(): Record<string, string> {
    return { Authorization: `Bearer ${this.token}` };
  }

  async device(): Promise<DeviceResponse> {
    const response = await fetch(apiUrl(this.base, "device"));
    if (!response.ok) throw new ApiError(response.status, "device request failed");
    return (await response.json()) as DeviceResponse;
  }

  async listPorts(): Promise<PortsResponse> {
    const response = await fetch(apiUrl(this.base, "ports"), { headers: this.headers() });
    if (!response.ok) throw new ApiError(response.status, await errorText(response));
    return (await response.json()) as PortsResponse;
  }

  async killPort(port: number, signal: KillSignal): Promise<string> {
    const response = await fetch(apiUrl(this.base, `ports/${port}/kill`), {
      method: "POST",
      headers: { ...this.headers(), "Content-Type": "application/json" },
      body: JSON.stringify({ signal }),
    });
    const body = (await response.json().catch(() => ({}))) as { outcome?: string; error?: string };
    if (!response.ok) throw new ApiError(response.status, body.error ?? "kill failed");
    return body.outcome ?? "signalled";
  }

  /** Opens an SSE connection; returns a disposer. */
  streamPorts(onSnapshot: (response: PortsResponse) => void, onError: () => void): () => void {
    const url = `${apiUrl(this.base, "events")}?token=${encodeURIComponent(this.token)}`;
    const source = new EventSource(url);
    source.addEventListener("ports", (event) => {
      const parsed = parsePortsEvent((event as MessageEvent<string>).data);
      if (parsed) onSnapshot(parsed);
    });
    source.onerror = onError;
    return () => source.close();
  }
}

async function errorText(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as { error?: string };
    return body.error ?? `HTTP ${response.status}`;
  } catch {
    return `HTTP ${response.status}`;
  }
}
