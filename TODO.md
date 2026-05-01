# TODO — Prioritized Remediation & Improvement Plan

## P0 — Critical (Do first)
- [ ] Remove plaintext credentials from Firestore `extraConfig`; migrate to secure storage and token references only.
- [ ] Define and enforce strict Firestore Security Rules with least privilege and field-level constraints.
- [ ] Add secret redaction policy for logs and exceptions (never log tokens/passwords/device secrets).
- [ ] Implement TLS pinning (or equivalent transport trust hardening) for cloud driver endpoints.

## P1 — High Priority
- [ ] Fix `DriverManager.bindDevice()` to dispose previous bound driver before replacement.
- [ ] Harden Kasa response parser to read length-prefixed payload safely with size limits.
- [ ] Add robust input validation for IP/MAC and brand-specific required fields in Add Device UX.
- [ ] Refactor `DeviceListScreen` sign-out to use injected Riverpod auth provider (testable DI).
- [ ] Add auth/session timeout handling and explicit re-auth UX for cloud drivers.

## P2 — Reliability & Performance
- [ ] Introduce retry/backoff with jitter and circuit breaker patterns for network calls.
- [ ] Debounce/coalesce frequent control updates (brightness sliders) to reduce traffic and battery use.
- [ ] Implement local cache/offline mode using Isar (already in dependencies).
- [ ] Add lifecycle monitoring to ensure all sockets/HTTP clients are disposed on sign-out/app background.

## P3 — UX, Accessibility, and Product Quality
- [ ] Add contextual error states with actionable remediation guidance (instead of raw exception text).
- [ ] Provide onboarding for permission scopes (local network, account linking, privacy choices).
- [ ] Add accessibility audit pass (screen-reader labels, contrast, focus order, dynamic text).
- [ ] Add optimistic UI with rollback messaging for command failures.

## P4 — Governance, Privacy, and Compliance
- [ ] Add privacy documentation: data inventory, retention policy, deletion/export flows.
- [ ] Minimize sensitive telemetry (IP/MAC/state history) and define retention windows.
- [ ] Add secure SDLC checklist and threat modeling artifacts for each driver/protocol.

## Validation Milestones
- [ ] Firestore emulator tests for rule enforcement.
- [ ] Unit tests: serialization excludes secrets; parser hardening edge cases.
- [ ] Integration tests: rebind lifecycle, offline recovery, auth refresh.
- [ ] Security test pass: MITM simulation, replay attempts, authorization boundary checks.
