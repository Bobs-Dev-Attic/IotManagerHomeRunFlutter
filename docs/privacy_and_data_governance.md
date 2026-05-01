# Privacy & Data Governance

## Data inventory
- Account identifiers (Firebase UID, email for auth).
- Device metadata (display name, brand, type, model).
- Network metadata for local control (IP and optional MAC).
- Live state (online status, power state, brightness).

## Retention policy
- Device inventory and settings: retained until user deletes the device.
- Diagnostic logs: keep 14 days max, secrets redacted.
- Telemetry aggregates (non-identifying reliability counters): keep 30 days.
- No raw command payload history retention by default.

## Deletion and export flows
- In-app deletion removes `users/{uid}/devices/{deviceId}` and associated live state.
- Account deletion should trigger backend cleanup for all user-scoped documents.
- Data export flow: user can request a JSON export containing non-secret device metadata and preferences.

## Telemetry minimization policy
- Do not collect full IP/MAC in analytics events.
- Use coarse counters only (success/failure, latency buckets, driver type).
- Store only short-lived identifiers required for incident triage.
