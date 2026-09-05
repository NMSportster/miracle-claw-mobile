# Miracle Claw Mobile — Build Plan

**Project**: `miracle-claw-mobile`
**Target**: Android + iOS (iOS added 2026-09-04 per David — worldwide distribution)
**Backend**: `api.maicserver.com` (MAIC public, Hetzner canonical)
**Desktop companion**: `miracle-claw` Tauri app, `1.1.0-rc55.18`
**Repo**: `https://github.com/NMSportster/miracle-claw-mobile` (new)
**Bundle ID**: `com.milagrocloud.miracle-claw.mobile`
**Authored**: 2026-09-04 by Home Claw + David

---

## Platform targets

- **Android**: min SDK 24 (Android 7.0 Nougat, 2016). Covers ~98% of active Android devices.
- **iOS**: deployment target 15.0. Covers iPhone 6s/7+ and newer, ~97% of in-use iPhones.
- **Linux desktop**: scaffold removed (dev-only convenience not needed).

---

## Why this app exists

Miracle Claw desktop is a Tauri 2 chat client wrapping the OpenClaw chat gateway (bundled Node + openclaw.mjs) which fronts MAIC at `https://api.maicserver.com`. Everything in the desktop — auth, sessions, streaming chat, modules, tools, voice, secrets vault — ultimately calls MAIC's `/v1/*` REST surface.

The mobile app is **a Flutter-native client for the same MAIC surface**, with two operating modes:

1. **Direct mode** (default): phone talks straight to `https://api.maicserver.com` with the user's MAIC JWT. Works anywhere. Zero desktop dependency.
2. **Desktop-paired mode** (opt-in): phone routes through a desktop on Tailscale, picking up the desktop's modules, secrets vault, voice config, and BYO provider keys automatically.

Both modes share one auth, one chat engine, one local cache. The phone should feel like the same app.

---

## What I learned from reading the desktop source (rc55.18)

| Discovery | File | Impact on mobile |
|---|---|---|
| OpenClaw gateway binds loopback by default; `--bind tailnet` is wired in `launcher.rs` but not exposed in UI | `src-tauri/src/launcher.rs` lines 18-21 | Mobile pairing needs a small desktop patch to expose `mc_get_pairing_qr` + a Settings toggle for `--bind tailnet` |
| Tauri commands `maic_login`, `maic_logout`, `silent_relogin`, `mc_get_tier`, `mc_list_tools`, `mc_voice_native_capture`, etc. | `src-tauri/src/lib.rs` invoke_handler | Mobile doesn't need to call these — it talks MAIC directly using the same `/v1/users/login` flow |
| Auth: `POST {MAIC_API_URL}/v1/users/login` → JWT; cached creds AES-256-GCM in OS keychain for silent relogin | `src-tauri/src/auto_relogin.rs` | Mobile mirrors the same flow, stores JWT in `flutter_secure_storage` (Android Keystore-backed) |
| MAIC endpoint overridable via `MAIC_API_URL` env var, normalized to strip `/v1` suffix | `src-tauri/src/lib.rs` `maic_login` | Use `--dart-define=MAIC_API_URL=...` for build-time override + Settings UI override |
| `POST /v1/chat/completions` is streaming SSE | `src/secrets/preprocessor.js`, `dist/types.openclaw-CXjMEWAQ.d.ts` | Mobile uses `http.Client.send()` + line-delimited SSE parser |
| `POST /v1/responses` (OpenResponses API) exists in rc55+ | `dist/types.openclaw-CXjMEWAQ.d.ts` | Plan v1 for chat/completions; add /v1/responses as v1.1 once MAIC's coverage is confirmed |
| 7+ paid-tier tool names per `data/module-help.js` (calendar, crm, email, firecrawl, leadgen, ocr, pdf, translate, tts, voice, youtube — 16 modules per MEMORY) | `src/data/module-help.js` | Mobile surfaces tools as buttons but invokes via paired desktop (not local) — keeps model/tool parity with desktop |
| Capabilities are strictly scoped per webview; `bridge.json` only allows 3 commands on `127.0.0.1:28789`, not shell/fs | `src-tauri/capabilities/bridge.json` | Pattern for desktop-side pairing: a separate `mobile-bridge.json` capability for tailnet-bound webview, only `mc_get_pairing_qr` + a session mint |
| State dir: `~/.miracle-claw/` (nix) / `%APPDATA%\MiracleClaw\` (Win) | `src-tauri/src/lib.rs` first_run_path | Pairing token persists in this dir; phone discovers it via QR |

---

## Architecture

```
┌──────────────────────────┐                ┌──────────────────────────┐
│  Flutter (Android)       │                │  Miracle Claw Desktop    │
│                          │                │  (Tauri + bundled        │
│  - Riverpod state        │                │   OpenClaw gateway on    │
│  - Drift local cache     │                │   127.0.0.1:28789)       │
│  - Dio HTTP + SSE parser │                │                          │
│  - flutter_secure_storage│                │  - mc_get_pairing_qr     │
│  - WebSocket (push)      │                │  - OpenClaw gateway      │
│  - mobile_scanner (QR)   │                │  - MAIC proxy            │
│  - speech_to_text + TTS  │                │                          │
└──────────┬───────────────┘                └──────────┬───────────────┘
           │                                          │
           │ HTTPS (REST + SSE + WSS)                 │
           ▼                                          ▼
              ┌──────────────────────────────────────┐
              │  api.maicserver.com (Hetzner MAIC)   │
              │  /v1/users/login    (auth)           │
              │  /v1/users/me      (profile + tier)  │
              │  /v1/users/me/sessions (sync)        │
              │  /v1/chat/completions (SSE stream)   │
              │  /v1/users/me/devices (push tokens)  │
              │  /v1/billing/plans + checkout        │
              └──────────────────────────────────────┘
```

**Two connection modes**:

| Mode | When | Where requests go | Latency | Capabilities |
|---|---|---|---|---|
| **Direct** | Default. Always available. | `https://api.maicserver.com` | 50-300ms | Login, chat, sessions, history, billing |
| **Paired** | Desktop on same tailnet, QR-paired | `http://<tailscale-ip>:28789` (proxy to MAIC) | 5-30ms LAN | All of direct + desktop modules + secrets vault + voice + BYO provider keys |

When paired-mode URL is unreachable, automatic fallback to direct with a non-blocking banner ("Using cloud mode — desktop unavailable").

---

## Project layout

```
miracle-claw-mobile/
├── pubspec.yaml              name: miracle_claw_mobile, desc: "Miracle Claw mobile companion"
├── android/                  standard Flutter Android shell (Kotlin, minSdk 24, targetSdk 35)
├── lib/
│   ├── main.dart             entrypoint, runs ProviderScope + app
│   ├── app.dart              MaterialApp.router, theme, go_router config
│   ├── theme/
│   │   ├── colors.dart       MAIC brand palette (Milagro green/dark)
│   │   └── theme.dart        Material 3 dark + light
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart       dio instance, interceptors, retry, logging
│   │   │   ├── auth_interceptor.dart JWT injection + 401 retry
│   │   │   ├── sse_client.dart       Server-Sent Events parser
│   │   │   └── ws_client.dart        WebSocket push
│   │   ├── auth/
│   │   │   ├── auth_repository.dart  login, logout, refresh, silent relogin
│   │   │   ├── secure_storage.dart   flutter_secure_storage wrapper
│   │   │   └── biometric_gate.dart   local_auth wrapper for re-auth
│   │   ├── config/
│   │   │   └── app_config.dart       MAIC_API_URL, build flavor, env
│   │   └── errors/
│   │       └── app_error.dart        typed exceptions, user-friendly messages
│   ├── data/
│   │   ├── db/
│   │   │   ├── database.dart         Drift schema + DAO exports
│   │   │   ├── tables.dart           sessions, messages, outbox, modules_cache
│   │   │   └── daos/                 per-table DAOs
│   │   ├── models/                   freezed models (Session, Message, ToolCall, Module)
│   │   └── repositories/
│   │       ├── session_repository.dart  local-first CRUD + sync
│   │       ├── message_repository.dart  stream + outbox
│   │       └── module_repository.dart   tools list from desktop
│   ├── features/
│   │   ├── auth/
│   │   │   ├── login_screen.dart        email/password form, "stay signed in"
│   │   │   ├── biometric_prompt.dart    re-auth gate
│   │   │   └── qr_pair_screen.dart      scan desktop QR
│   │   ├── chat/
│   │   │   ├── sessions_list_screen.dart  paginated, search, swipe-delete
│   │   │   ├── chat_screen.dart           streaming, markdown, tool cards
│   │   │   ├── message_bubble.dart        user/assistant/tool variants
│   │   │   └── composer.dart              text + voice input
│   │   ├── voice/
│   │   │   └── voice_input.dart           speech_to_text, hold-to-talk
│   │   ├── modules/
│   │   │   └── modules_screen.dart        list, status, "invoke" button
│   │   ├── settings/
│   │   │   ├── settings_screen.dart       account, endpoint, plan, pairing
│   │   │   └── endpoint_screen.dart       MAIC_API_URL override + test
│   │   └── shell/
│   │       └── home_shell.dart            nav rail (sessions, modules, settings)
│   ├── services/
│   │   ├── push_service.dart             FCM registration, background handler
│   │   ├── sync_service.dart             workmanager outbox flush
│   │   └── connectivity_service.dart     online/offline + tailnet reachability
│   └── l10n/
│       ├── app_en.arb
│       └── app_es.arb                   Albuquerque + Southwest US market
├── assets/
│   ├── brand/
│   │   ├── icon-foreground.png           from miracle-claw/brand/
│   │   └── splash.png
│   └── fonts/                            Inter (already in web stack per miracle-claw/src/styles.css)
├── test/
│   ├── widget/                           widget tests per screen
│   ├── unit/                             repository, auth, SSE parser
│   └── integration/                      end-to-end login + chat
└── PLAN.md                               this file
```

---

## Phases

### Phase 0 — Scaffold (done 2026-09-04)

- Folder: `/home/adeal/.openclaw/workspace/projects/miracle-claw-mobile/`
- Flutter create: `flutter create --org com.milagrocloud --project-name miracle_claw_mobile --platforms android,linux`
- Bundle ID: `com.milagrocloud.miracle-claw.mobile`
- Git init + remote: `https://github.com/NMSportster/miracle-claw-mobile`
- Default README replaced with project overview
- This PLAN.md committed

### Phase 1 — Auth + Direct MAIC mode (~2 days)

- `core/config/app_config.dart` — read `MAIC_API_URL` from `--dart-define`, default `https://api.maicserver.com`
- `core/api/api_client.dart` — dio with auth interceptor, retry on 401
- `core/auth/auth_repository.dart` — `login(email, password, remember)`, `logout()`, `silentRelogin()`, persists JWT in secure storage
- `core/auth/biometric_gate.dart` — `local_auth` wrapper for re-auth after cold start
- `features/auth/login_screen.dart` — UI matching desktop's `pages/login.js` style (dark, Milagro branding)
- `features/settings/endpoint_screen.dart` — override MAIC_API_URL, with "test connection" button
- **Verification**: log in as `test1@milagrocloud.com` (canonical test user, MEMORY.md), see profile + tier pulled from `/v1/users/me`

### Phase 2 — Chat UI + offline cache (~2.5 days)

- `data/db/` — Drift schema with `sessions`, `messages`, `outbox` tables; 30-day cache window
- `data/repositories/session_repository.dart` — local-first with `since=<ts>` sync to `/v1/users/me/sessions`
- `data/repositories/message_repository.dart` — append + sync, idempotency on `client_id`
- `core/api/sse_client.dart` — SSE line parser, stream chunks into Riverpod
- `features/chat/sessions_list_screen.dart` — paginated, search, swipe-delete, last-sync timestamp
- `features/chat/chat_screen.dart` — streaming with auto-scroll, pause-on-scroll, markdown rendering, tool invocation cards
- `services/connectivity_service.dart` — online/offline events
- `services/sync_service.dart` — `workmanager` background outbox flush, retries with backoff
- **Verification**: start a session offline, watch messages queue, reconnect, watch them send in order

### Phase 3 — QR pairing to desktop gateway (~1.5 days, includes a small desktop patch)

**Mobile changes:**
- `features/auth/qr_pair_screen.dart` — `mobile_scanner`, captures `{host, port, token, fingerprint}`
- `core/api/api_client.dart` — add `baseUrl` switching logic: paired URL if reachable, else direct
- `core/config/app_config.dart` — paired-mode state, persisted
- `services/connectivity_service.dart` — probe paired URL health every 30s

**Desktop changes** (separate PR to `miracle-claw` repo, not this one):
- New Tauri command `mc_get_pairing_qr` in `src-tauri/src/lib.rs`:
  ```rust
  #[tauri::command]
  async fn mc_get_pairing_qr(window: tauri::Window) -> Result<PairingQr, String> { ... }
  ```
  Returns `{host: tailnet_ip_or_lan_ip, port: 28789, token: base64url_32B_5min_TTL, fingerprint: sha256(public_key), expires_at}`
- New capability `src-tauri/capabilities/mobile-bridge.json` — scoped to tailnet URLs only, allows `mc_get_pairing_qr` + `mc_mint_session` + `mc_get_modules`
- New Settings page `pages/mobile_pairing.js` — shows QR, status ("paired with 2 devices"), revoke button
- Update launcher invocation in `setup()` to support `--bind tailnet` (already wired in launcher.rs, just need UI toggle)
- On successful phone verification, desktop mints a session JWT scoped to mobile capabilities (no shell exec, no filesystem, only chat + module list + invoke)

**Verification**: pair from phone → phone routes chat through desktop gateway → desktop's modules appear in mobile app → kill desktop → phone auto-falls-back to direct MAIC within 30s

### Phase 4 — Push notifications + background sync (~1 day)

- Add FCM to project (see "Firebase setup" below)
- `services/push_service.dart` — register token on login, send to MAIC at `POST /v1/users/me/devices`
- Background handler: `firebase_messaging_background_handler`, defers to `sync_service` for outbox
- Two notification types:
  - `chat.completed` (reply ready, tap → open session)
  - `tool.needs_approval` (paid-tier tool requires user tap to execute)
- **Verification**: trigger a long chat from desktop, see phone notification, tap → opens session

### Phase 5 — Polish + ship (~2 days)

- Brand assets from `miracle-claw/brand/`
- Adaptive icon (Android 12+)
- Haptic feedback, error/empty/loading states
- Accessibility: semantics labels, contrast, font scaling
- Tablet layout (sessions list as side panel)
- Build APK + AAB, sign with Miracle keystore
- Play Store internal test track first
- Privacy policy URL: `https://milagrocloud.com/privacy` (already exists per MEMORY)
- Terms: `https://milagrocloud.com/terms`

**Total estimated effort**: ~9 dev days (5-6 calendar days solo)

---

## Open questions / dependencies

### Firebase (FCM)

David said "we probably need it." Plan:
1. Create a Firebase project under the MAIC Google Cloud org (or David's personal GCP)
2. Add Android app with bundle ID `com.milagrocloud.miracle-claw.mobile`
3. Download `google-services.json` → `android/app/`
4. Add `firebase_core` + `firebase_messaging` to pubspec
5. FCM free tier (unlimited push, no cost) is fine for our volume

**Action item**: David to create Firebase project + download config, share `google-services.json` (or I can guide him through the console clicks — 5 minutes of clicking).

### Brand assets

MiracleClaw logo + colors should already be in `miracle-claw/brand/` per desktop. Need to copy into `miracle-claw-mobile/assets/brand/`. Confirm in Phase 5.

### MAIC API surface

Confirmed working (per MEMORY):
- `POST /v1/users/login` ✅
- `GET /v1/users/me` ✅
- `GET /v1/users/me/usage` ✅
- `POST /v1/chat/completions` ✅ (streaming)
- `GET /v1/billing/plans` ✅

**To verify before Phase 1**:
- `GET /v1/users/me/sessions` — exists?
- `GET /v1/users/me/devices` — exists for FCM token registration?
- `POST /v1/webhooks/register` — exists for completion callbacks?

If any of these don't exist yet, small backend PRs to `milagro_ai_cloud` (a few hours each).

### Desktop patch (Phase 3)

This is a separate PR to `miracle-claw`. Should not block mobile Phase 1 + Phase 2 from shipping.

---

## What this app is NOT

- Not a local model runner (MAIC-only; no Ollama-on-phone)
- Not a module installer (read-only listing; full install stays desktop-only)
- Not a chat UI redesign (intentionally mirrors desktop's UX so phone and desktop feel like one app)

---

## Repository

- **Remote**: `https://github.com/NMSportster/miracle-claw-mobile`
- **Branch**: `master` (matches desktop convention)
- **Visibility**: public (matches desktop)
- **License**: Other / Milagro Distribution Corp proprietary (matches desktop)

---

## Carry-forward rules

- When adding new Tauri-side commands for mobile pairing, scope them under `mobile-bridge` capability, NEVER add to `main.json` or `bridge.json`.
- Mobile paired-mode tokens must be single-use + short-TTL. Never embed a long-lived MAIC JWT in a QR code.
- Don't replicate MAIC's auth state on mobile — always go through `/v1/users/login`. Don't invent a parallel auth path.
- When adding endpoints to MAIC for mobile use, follow the existing naming: `/v1/users/me/...` for per-user resources, `/v1/admin/...` for master-key gated.
- Test users for development: `test<N>@milagrocloud.com` (canonical convention per MEMORY). NEVER use `championnm@yahoo.com` for mobile testing — same lockout risk as desktop agent.
