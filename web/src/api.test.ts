import { describe, expect, it } from "vitest";
import { apiUrl, parsePortsEvent } from "./api";

describe("apiUrl", () => {
  it("joins base and path", () => {
    expect(apiUrl("https://host:7333", "ports")).toBe("https://host:7333/api/v1/ports");
  });

  it("tolerates trailing and leading slashes", () => {
    expect(apiUrl("https://host:7333/", "/ports/3000/kill")).toBe(
      "https://host:7333/api/v1/ports/3000/kill",
    );
  });
});

describe("parsePortsEvent", () => {
  it("parses a ports payload", () => {
    const parsed = parsePortsEvent('{"apiVersion":1,"ports":[{"port":3000}]}');
    expect(parsed?.ports).toHaveLength(1);
  });

  it("ignores SSE comments and blank lines", () => {
    expect(parsePortsEvent(": keep-alive")).toBeNull();
    expect(parsePortsEvent("   ")).toBeNull();
  });

  it("ignores non-ports JSON", () => {
    expect(parsePortsEvent('{"apiVersion":1}')).toBeNull();
    expect(parsePortsEvent("not json")).toBeNull();
  });
});
