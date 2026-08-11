# pos_application

A point-of-sale monorepo: two Flutter apps sharing one Firestore/Auth backend.

- `apps/pos_app` — staff-facing app, order-taking and live menu
- `apps/manager_app` — admin-facing app (scaffold, not yet built out)
- `packages/core` — shared entities, repository contracts, and Firestore/Auth datasources used by both apps

## Prerequisites

- Flutter (stable channel)
- Firebase CLI (`npm install -g firebase-tools`), logged in via `firebase login`
- CocoaPods, if building for iOS/macOS

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
