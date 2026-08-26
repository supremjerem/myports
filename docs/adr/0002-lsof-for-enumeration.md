# 2. Use `lsof` for port enumeration, `libproc` only for enrichment

Date: 2026-08-26

## Status

Accepted

## Context

To list listening TCP ports and map each to a process we can either:

- **Parse `lsof`** (`/usr/sbin/lsof -nP -iTCP -sTCP:LISTEN -F …`): always present
  on macOS, stable field-mode output, handles permissions gracefully (it simply
  omits what the caller may not see).
- **Call `libproc` directly** (`proc_listpids`, `proc_pidfdinfo` with
  `PROC_PIDFDSOCKETINFO`): no subprocess, faster, but much more C-interop, more
  fragile across OS releases, and still limited to the caller's own processes
  without elevated rights.

Neither approach sees other users' processes without root; that is acceptable
because the target user is inspecting their own dev servers.

## Decision

- Enumerate sockets by running `lsof` and parsing its `-F` output
  (`LsofParser`). The subprocess cost (tens of milliseconds) is irrelevant at a
  2-second poll interval.
- Use `libproc`/`sysctl` only to *enrich* a process we already found: absolute
  executable path (`proc_pidpath`), parent pid and start time
  (`proc_pidinfo(PROC_PIDTBSDINFO)`), and arguments (`KERN_PROCARGS2`). Every
  enrichment field is best-effort and degrades to `nil`.
- Keep both behind protocols (`CommandRunner`, `ProcessInspecting`) so tests run
  against recorded fixtures with no subprocess.

## Consequences

- A hard dependency on `/usr/sbin/lsof` existing and keeping its `-F` format.
  Fixture tests will catch a format drift on a future OS.
- If `lsof` ever proves too slow or unavailable, `PortScanner` is the only unit
  that changes; the models and everything above stay put.
