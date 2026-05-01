# Agent Context Pack (Token-Efficient)

Use this file first before scanning the codebase.

## Project Snapshot
- Flutter IoT manager (Kasa local TCP, Cync cloud, Leviton cloud, Matter channel).
- State management: Riverpod.
- Backend: Firebase Auth + Firestore.

## High-Risk Files
- `lib/core/models/device_model.dart` — serializes `extraConfig` directly.
- `lib/drivers/cync/cync_driver.dart` — email/password auth + bearer token.
- `lib/drivers/leviton/leviton_driver.dart` — email/password auth + token header.
- `lib/drivers/kasa/kasa_driver.dart` — raw TCP + custom parsing path.
- `lib/core/drivers/driver_manager.dart` — bind/dispose lifecycle.
- `lib/features/devices/presentation/screens/add_device_screen.dart` — validation UX.

## First Commands
- `flutter test`
- `dart analyze`

## Known Architectural Gaps
- Secrets management strategy not implemented.
- Firestore rules not included in repo.
- Isar dependency present but not integrated.

## Change Strategy
1. Security first (secrets, rules, transport).
2. Reliability second (lifecycle, parser, retries).
3. UX/accessibility third.

## Output Discipline
- Prefer concise diff-driven changes.
- Update `TODO.md` when adding/removing priorities.
- Keep docs actionable with owner + risk + acceptance criteria.
