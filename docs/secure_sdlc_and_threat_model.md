# Secure SDLC Checklist & Threat Model Artifacts

## Secure SDLC checklist (per driver/protocol)
- [ ] Threat model updated for protocol trust boundaries.
- [ ] AuthN/AuthZ review completed.
- [ ] Secret handling review (storage, transport, logs).
- [ ] Input validation and parser boundary tests.
- [ ] Dependency and license scan.
- [ ] Abuse-case tests (replay, tampering, MITM, brute force).
- [ ] Incident response owner and rollback plan documented.

## Threat model artifact template
For each driver (`kasa`, `cync`, `leviton`, `matter`) document:
1. Assets: credentials, device control channel, state integrity.
2. Entry points: local socket, cloud API, mobile UI, Firestore sync.
3. Trust boundaries: device LAN, app runtime, Firebase backend, third-party cloud.
4. Threats (STRIDE): spoofing, tampering, repudiation, information disclosure, DoS, privilege escalation.
5. Mitigations and test evidence links.
