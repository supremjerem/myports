export interface ConnectionDTO {
  localHost: string;
  localPort: number;
  remoteHost: string | null;
  remotePort: number | null;
  state: string;
}

export interface PortDTO {
  port: number;
  host: string;
  transport: string;
  pid: number;
  command: string;
  friendlyName: string;
  category: string;
  executablePath: string | null;
  user: string;
  isLoopback: boolean;
  connectionCount: number;
  connections: ConnectionDTO[];
}

export interface PortsResponse {
  apiVersion: number;
  ports: PortDTO[];
}

export interface DeviceResponse {
  apiVersion: number;
  hostname: string;
  operatingSystem: string;
  readOnly: boolean;
}

export type KillSignal = "TERM" | "KILL";
