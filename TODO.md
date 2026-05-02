# TODO — Prioritized Roadmap

Priorities are ordered by impact × urgency. Items marked `[x]` are complete in
the current branch; everything else is open work.

Legend: **P0** = ship-blocker · **P1** = pre-launch · **P2** = launch+30
days · **P3** = quality bar · **P4** = post-launch · **Store** = required to
list publicly on Google Play / App Store.

---

## P0 — Critical (security & data integrity)

- [x] Remove plaintext credentials from Firestore `extraConfig`; redact via
  `_sanitizedExtraConfig`.
- [x] Enforce least-privilege Firestore Security Rules with field-level
  constraints and a sensitive-key allowlist.
- [x] Secret redaction in `AppLogger` for tokens/passwords/auth headers.
- [x] Driver-declared `sensitiveConfigKeys` automatically register with the
  serializer redactor (this PR).
- [ ] **Replace `secure://` redaction with real secret storage**:
  integrate `flutter_secure_storage` (Keychain/Keystore) and store an
  opaque alias in `extraConfig`. Drivers resolve the alias at
  `initialize()` time.
- [ ] **TLS certificate pinning** for `dio` clients in `CyncDriver` and
  `LevitonDriver` (use `dio` `IOHttpClientAdapter` + pinned SHA-256
  fingerprints; ship a rotation playbook).
- [ ] **Move cloud auth to a backend token broker** (Cloud Functions /
  Cloud Run) so the mobile app never holds long-lived vendor passwords.

## P1 — Pre-launch (reliability, lifecycle, validation)

- [x] `DriverManager.bindDevice()` disposes the previous instance before
  rebinding.
- [x] Length-prefixed Kasa parser with a 64 KiB max-payload guard.
- [x] IPv4 / MAC validation in `AddDeviceScreen`; brand-aware required
  fields.
- [x] Riverpod-based DI for `AuthRepository` (no widget-side construction).
- [x] 401 handling and re-auth signaling in cloud drivers.
- [x] `BaseDeviceDriver` extended with capability metadata, event stream
  hook, health check, version, manufacturer, discovery hook (this PR).
- [ ] **Capability-driven UI**: hide/disable controls when
  `driver.supports(...)` is false instead of relying on `UnsupportedError`
  at runtime.
- [ ] **Background health monitor** that calls `driver.healthCheck()` on a
  jittered interval and updates `isOnline` (no per-frame polling).
- [ ] **Account-deletion endpoint** wired to a Cloud Function that purges
  `users/{uid}/devices/*` plus secure-storage entries — required by the
  App Store **and** Google Play Data Safety policy.
- [ ] **Decouple `DeviceBrand` enum from driver registration**: prefer
  `extraConfig['_driverId']` so third-party drivers can ship without
  enum edits (resolver added in this PR; UI add-flow still needs to
  expose it).

## P2 — Launch + 30 days (resilience, observability, performance)

- [x] Retry-with-backoff + jitter, circuit breaker for cloud calls.
- [x] Brightness slider debounce (250 ms) with rollback on failure.
- [x] App-lifecycle dispose of bound drivers on `paused` / `detached`.
- [ ] Implement Isar-backed offline cache (the dependency is declared but
  unused). Suggested scope: device list mirror + last-known state + write
  outbox.
- [ ] Crashlytics / Sentry with PII redaction hooks; route the existing
  `AppLogger` through it.
- [ ] Per-driver command queue + dedupe to coalesce rapid commands beyond
  brightness (color, color-temp).
- [ ] Network-quality-aware timeouts (Wi-Fi vs cellular) using
  `connectivity_plus` (declared but unused).
- [ ] Replace polling `refreshStatus()` with the new `driver.events`
  stream where the driver supports `eventStreaming`.

## P3 — UX, accessibility, product quality

- [x] Actionable error messages via `remediationMessageForError`.
- [x] Optimistic UI with rollback on toggle/brightness.
- [x] Onboarding for permission scopes (local network, account linking).
- [x] Initial accessibility pass (semantic labels, helper text).
- [ ] Full a11y audit: dynamic-type scaling test, screen-reader walkthrough,
  WCAG 2.1 AA contrast checks for both themes.
- [ ] Brand-specific Add Device wizard with progressive disclosure (only
  show fields required by the selected driver's `configSchema`).
- [ ] Diagnostic screen: per-device health-check result, last error, raw
  driver info; gated behind Developer Mode.
- [ ] Discovery surface: render `driver.discover()` hints and mDNS results
  side-by-side in the Add Device flow.

## P4 — Governance, privacy, compliance

- [x] Privacy & data-governance doc.
- [x] Telemetry minimization policy.
- [x] Secure SDLC checklist & threat-model template.
- [ ] Public-facing **Privacy Policy URL** (required for store listings).
- [ ] Per-driver threat models filled in (Kasa, Cync, Leviton, Matter)
  using the template.
- [ ] Dependency / license SBOM and a CI scan (e.g. `osv-scanner`,
  `dependabot`). The current pubspec uses Firebase, Dio, Bonsoir, Isar —
  all must be tracked.
- [ ] DSAR flow: in-app export of non-secret device metadata + account
  deletion confirmation email.

## Store-readiness — Google Play & Apple App Store

### Google Play

- [ ] **Data Safety form** declaring: account creds (auth), device ID, IP,
  approximate location (LAN), diagnostic logs (if Crashlytics is added).
  Map every collected field with purpose, sharing, and retention.
- [ ] **Account deletion** in-app + web URL (Play policy, May 2024).
- [ ] **Target SDK 34+** (current `targetSdkVersion 34` ✅) — re-verify on
  each Play update.
- [ ] **Foreground service / local network use justification** in the
  listing if background polling is added.
- [ ] **Release signing**: `android/app/build.gradle` currently uses
  `signingConfig signingConfigs.debug` for `release` — must switch to a
  real keystore before upload.
- [ ] **App Bundle (.aab)** build pipeline.
- [ ] Privacy policy URL, support email, content rating questionnaire.
- [ ] Strip the `YOUR_REVERSED_CLIENT_ID` and `firebase_options.dart`
  placeholders before any production build.

### Apple App Store

- [ ] **App Privacy "Nutrition Label"** matching the Data Safety form.
- [ ] `NSLocalNetworkUsageDescription` ✅ already present — keep the copy
  user-friendly and accurate.
- [ ] Add `NSUserTrackingUsageDescription` only if any analytics SDK with
  IDFA is added (currently none).
- [ ] App Transport Security: confirm no `NSAllowsArbitraryLoads`. With
  TLS pinning (P0), define `NSPinnedDomains` for vendor APIs.
- [ ] Sign in with Apple — required if any other third-party social sign-in
  is offered. Google Sign-In is configured, so SIWA must be added before
  iOS submission.
- [ ] **Account deletion in-app** (Guideline 5.1.1(v), required since
  2022).
- [ ] Marketing screenshots, privacy policy URL, support URL.
- [ ] Bundle id, code-signing profile, push entitlements (only if push is
  added later).

## Validation milestones

- [ ] Firestore rules emulator tests covering: cross-user reads, sensitive
  field rejection, missing `userId`.
- [ ] Unit tests: `DeviceModel` redacts every key in
  `sensitiveExtraConfigKeys`; `DriverManager` registration auto-extends
  the redactor; capability gating returns false for unsupported ops.
- [ ] Integration tests: bind → rebind → dispose lifecycle; offline cache
  recovery; cloud auth refresh on 401.
- [ ] Security pass: MITM with mitmproxy against pinned endpoints; replay
  detection; IDOR against Firestore rules.
- [ ] Pre-submission: `flutter analyze` clean, `flutter test` green,
  `flutter build appbundle --release` and `flutter build ipa --release`
  succeed against placeholder-free `firebase_options.dart`.
