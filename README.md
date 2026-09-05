# Miracle Claw Mobile

Android companion app for [Miracle Claw](https://github.com/NMSportster/miracle-claw) desktop. Talks to MAIC at `api.maicserver.com` (or your paired desktop on Tailscale) so you can keep a conversation going from the truck to the bay to the desk.

## Status

Early scaffold (v0.0.1-dev). See [PLAN.md](./PLAN.md) for the build roadmap.

- [x] Folder + project scaffold
- [x] Plan documented
- [ ] Phase 1 — Auth + direct MAIC mode
- [ ] Phase 2 — Chat UI + offline cache
- [ ] Phase 3 — QR pairing to desktop
- [ ] Phase 4 — Push notifications
- [ ] Phase 5 — Polish + ship

## Stack

- Flutter 3.44 / Dart 3.12 (stable)
- Riverpod for state, go_router for navigation
- Dio for HTTP, custom SSE parser for streaming chat
- Drift for local cache (sqflite backend)
- flutter_secure_storage for JWTs (Android Keystore)
- mobile_scanner for QR pairing
- speech_to_text + flutter_tts for voice
- FCM for push
- workmanager for background outbox sync

## Backend

Default endpoint: `https://api.maicserver.com` (Hetzner MAIC). Override at build time:

```bash
flutter build apk --dart-define=MAIC_API_URL=https://staging.maicserver.com
```

Or in Settings → Endpoint after install.

## Desktop pairing

Optional. Open the desktop app (rc55.18+) → Settings → Mobile → tap "Show QR". Scan with the app. Routes chat through your desktop on Tailscale, picks up modules + secrets + voice config automatically. Falls back to direct MAIC when desktop unreachable.

## Bundle

- ID: `com.milagrocloud.miracle-claw.mobile`
- Brand: Milagro Distribution Corp
- Repo: https://github.com/NMSportster/miracle-claw-mobile

## Dev setup

```bash
cd ~/projects/miracle-claw-mobile
flutter pub get
flutter run -d <android-device-id>
```

Android SDK + Flutter paths assumed via `~/.openclaw/workspace` conventions (`~/flutter/bin/flutter`, `~/android-sdk`).

## License

© Milagro Distribution Corp. Proprietary. See LICENSE (TBD).
