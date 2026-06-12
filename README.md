# GCI Mobile

Native iOS/Android frontend (Flutter) for the GCI collective-intelligence
platform. Talks to the existing `gcibmn` FastAPI backend — no mobile-specific
server changes required.

## What's in the app

- **Auth** — email/password login, registration, forgot-password, and guest
  entry for jam invite links (mirrors the web guest flow).
- **Home shell** — Dashboard (created + contributing jams, archive/restore),
  Discover (public/active jams), Profile.
- **Participation loop** — prompt pager with probability slider + reasoning,
  peer review with Agree / Need Info / Disagree and tap-to-rank priority
  ordering, SSE-driven "waiting for peers" room with polling fallback.
- **Results** — participation funnel chart, per-prompt consensus, top ideas.
- **Light creator** — 2-step create & launch flow, share-sheet invite links.
- **Deep links** — `https://crowdsmart.ai/jam/:id/participate` (and legacy
  `/collaborate/:id`) open directly in the app.

## Architecture

```
lib/
  core/       config (dart-define), theme, secure session store
  api/        Dio client + JWT interceptor, typed models, GciRepository
  features/
    auth/     login / register / forgot password, Riverpod auth controller
    home/     bottom-nav shell, dashboard, discover, profile
    jam/      jam detail, participate (predict + review steps), results
    create/   create & launch jam
  widgets/    shared loading/error/empty views, jam cards
```

State management is Riverpod; navigation is go_router (routes mirror the web
app URLs so deep links Just Work); networking is Dio with the JWT stored in
`flutter_secure_storage`; live updates use the backend's SSE channel
(`GET /api/jams/{id}/events`).

## Running

```bash
flutter pub get

# Against the production API (defaults)
flutter run

# Against a local backend
flutter run --dart-define=API_BASE_URL=http://localhost:8000 \
            --dart-define=WEB_ORIGIN=http://localhost:3000
```

`API_BASE_URL` and `WEB_ORIGIN` are compile-time flags (see
`lib/core/config.dart`); defaults point at the deployed Render API and
crowdsmart.ai.

## Checks

```bash
flutter analyze
flutter test
```

CI (GitHub Actions) runs analyze + tests and a debug Android build on every
push/PR.

## Deep-link server prerequisites

Link handling is configured in the app (Android App Links intent filter,
`FlutterDeepLinkingEnabled` on iOS), but verified links also need files served
from the web origin:

- **Android**: `https://crowdsmart.ai/.well-known/assetlinks.json` listing the
  app's package name and signing-cert SHA-256.
- **iOS**: `https://crowdsmart.ai/.well-known/apple-app-site-association` with
  the app ID, plus the `applinks:crowdsmart.ai` Associated Domains
  entitlement added in Xcode (requires the Apple team's signing config).

## Release / distribution

- **Icons & splash**: drop the master icon at `assets/icon.png` and use
  `flutter_launcher_icons` / `flutter_native_splash` to generate platform
  assets (the in-app branded splash already exists).
- **iOS (TestFlight)**: open `ios/Runner.xcworkspace` in Xcode, set the team +
  bundle ID, then `flutter build ipa` and upload via Transporter or
  `xcrun altool`.
- **Android (Play internal testing)**: create an upload keystore, configure
  `android/key.properties`, then `flutter build appbundle` and upload the
  `.aab` to an internal testing track.
