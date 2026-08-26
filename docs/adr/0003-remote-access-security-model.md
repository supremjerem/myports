# 3. Remote access security model

Date: 2026-08-26

## Status

Accepted (design; implemented in Phase 3)

## Context

The agent (`portsd serve`) will expose port listing **and process killing** over
the network so an iOS app or a browser can act on a paired machine. A remote
"kill the process on port N" is effectively remote code execution against the
host, so the transport and authorization model must be deliberate rather than an
afterthought.

## Decision

1. **Loopback by default.** The agent binds `127.0.0.1`. LAN exposure
   (`0.0.0.0`) is a separate, explicit opt-in (`--lan` / a toggle in the macOS
   app), never the default.
2. **TLS always.** A self-signed certificate is generated on first run and
   stored in the Keychain. Its fingerprint is shown to the user and embedded in
   the pairing payload; clients pin it. No plaintext HTTP, even on loopback.
3. **Explicit pairing.** The macOS app shows a QR code carrying
   `{ host, port, certFingerprint, pairingToken }`. `pairingToken` is
   single-use and short-lived; the client exchanges it (`POST /api/v1/pair`) for
   a long-lived per-client bearer token. Tokens are listed and individually
   revocable in the app.
4. **Read-only mode.** `MYPORTS_READONLY=true` lets paired clients view ports but
   rejects every kill with HTTP 403.
5. **Audit log.** Every kill attempt (local or remote) is appended to a log the
   app can display: timestamp, client identity, port, pid, signal, outcome.
6. **Rate limiting.** Kill endpoints are rate-limited per client token.
7. **Versioned contract.** Responses carry `apiVersion`; the client refuses or
   warns on a mismatch it cannot handle.

## Consequences

- More moving parts in Phase 3 (cert lifecycle, token store, pairing UI) before
  remote access is usable, which is why the macOS app (Phase 2) ships first with
  no network surface at all.
- Self-signed + pinning means no browser "just works" over the LAN without
  accepting the certificate once; the served web UI documents this.
- The audit log and read-only mode give the user a way to expose the agent on a
  trusted LAN without fully trusting every device on it.
