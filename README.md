# pos_application

A point-of-sale monorepo: two Flutter apps sharing one Firestore/Auth backend.

- `apps/pos_app` — staff-facing app: live menu, order-taking/cart, checkout
- `apps/manager_app` — admin-facing app: menu item create/edit/delete, availability toggling
- `packages/core` — shared entities, repository contracts, and Firestore/Auth datasources used by both apps

**Reviewing this submission?** The recorded demo is the primary way to see this working end to end. If you'd rather run it yourself, skip straight to ["Running this yourself (for graders)"](#running-this-yourself-for-graders) below — it doesn't require your own Firebase project. Everything from "Prerequisites" through "Firestore security rules" is written for someone continuing to build on this codebase, not a required review step.

## Running this yourself (for graders)

No Firebase project, CLI, or login of your own needed — the Firebase config for my project is already checked into this repo (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart` for each app), so both apps connect to my live Firestore/Auth out of the box.

```bash
cd apps/pos_app && flutter pub get && flutter run      # staff app — run on iOS or Android
cd apps/manager_app && flutter pub get && flutter run  # manager app — run on iOS or Android
```

(Only iOS and Android are configured — see "Prerequisites" below for why.)

Sign in with:

- **Manager app (admin):** `jordannnabugwu@gmail.com` / `possystem`
- **POS app (staff):** `dialannabugwu@gmail.com` / `possystem2`

These are throwaway accounts scoped to this one demo Firebase project — not tied to any payment method or real data. To see the live-sync requirement, run both apps at once (two simulators, or a simulator + a physical device) and edit the menu from the manager app while watching the POS app update without a restart.

## Prerequisites

- Flutter (stable channel)
- Firebase CLI (`npm install -g firebase-tools`), logged in via `firebase login`
- CocoaPods, if building for iOS
- Supported targets: **iOS (iPhone + iPad) and Android (phone + tablet) only** — both apps are scoped to mobile, matching the assignment's tablet/phone layouts. macOS, web, Linux, and Windows are deliberately not configured (see "What I'd build next").

## Setup

From the repo root:

```bash
firebase use --add          # link this checkout to your Firebase project
```

Each app is a standalone Flutter project with a path dependency on `packages/core`. Get dependencies per app:

```bash
cd apps/pos_app && flutter pub get
cd apps/manager_app && flutter pub get
cd packages/core && flutter pub get
```

## Running an app

```bash
cd apps/pos_app
flutter run
```

Swap `pos_app` for `manager_app` to run the other one.

## Firestore security rules

Rules live at the repo root (`firestore.rules`, `firestore.indexes.json`) and apply to both apps, since they share one Firestore project. Deploy from the repo root:

```bash
firebase deploy --only firestore:rules
```

To iterate on rules locally without touching prod data:

```bash
firebase emulators:start --only firestore
```

## Tests, formatting, analysis

Run per package (`packages/core`, `apps/pos_app`, `apps/manager_app`):

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

CI (`.github/workflows/code_quality.yml`) runs all three across every package on every push/PR to `main`.

## Docs

See [`docs/architecture-decisions.md`](docs/architecture-decisions.md) for the reasoning behind the monorepo layout, Bloc-over-Cubit default, and Firebase-vs-backend split.

## What I'd build next with more time

- **Order history / receipts.** Checkout persists orders to Firestore (`orders`), but nothing reads them back yet — staff/admin have no way to look up a past order.
- **Payment capture.** Checkout records the order; it doesn't move any money. Payment integration is a real backend/PCI-scope decision, not something to bolt on casually.
- **Role management UI.** Admin/staff accounts and their `users/{uid}` role docs are still created by hand in the Firebase Console (see Setup) — a real invite/role-management screen would remove that manual step.
- **Automated Firestore rules tests.** `firestore.rules` now encodes a real business invariant (staff can decrease menu stock via checkout, never increase it — see [`docs/lessons.md`](docs/lessons.md) §5), verified manually against the emulator so far. A `@firebase/rules-unit-testing` suite would catch a future regression in the rules themselves, not just the app code.
- **Signed release builds.** This build targets debug/dev runs on the platforms actually exercised during development (see Prerequisites). Shipping to app stores needs real bundle ids, signing certificates, and store listings — deliberately out of scope for the demo.
- **Offline support.** Both apps currently assume a live connection. Firestore's offline persistence is available but not enabled/tested here.
- **Melos.** Right now each app/package gets `flutter pub get`/`flutter test`/`flutter analyze` run against it individually (see "Setup" and "Tests, formatting, analysis" above) — fine for two apps and one shared package, but it's already three separate commands per action. Melos would collapse that into one bootstrap + one `melos run test`/`melos run analyze` across the whole monorepo, and become worth it for real once a third app or package shows up.

## AI tools used, and for what

I used Claude Code (Anthropic's Sonnet 5) throughout this build: architecture planning and back-and-forth before writing code, implementing both apps and the shared `packages/core` package, writing the unit/Bloc test suites, and working through two rounds of automated review from `cubic-dev-ai` on the GitHub PRs for this repo. **[`docs/lessons.md`](docs/lessons.md) is the detailed technical write-up of that review cycle** — not a list of what got fixed, but the small set of recurring root causes behind the findings (discarded `Either` results, two independent copies of the same auth state, money/inventory validation needing to live in the security rules rather than only the form, and so on) that are worth carrying into the next feature, not just this one.