# Flutter Monorepo Starter (Multi-app + Firestore + optional FastAPI)

> Builds on [victoria.md](./victoria.md). That doc explains the stack from scratch for a first-time reader; this one assumes you already know the terms and just want the shape, with two changes: (1) **multiple Flutter apps sharing one codebase**, not one app + one API, and (2) **Bloc over Cubit** as the default state-management call, not Bloc-only.

---

## 1. Stack

- **Flutter** — N client apps (this doc assumes 2: e.g. a "staff-facing" app and an "admin-facing" app) sharing one Dart codebase.
- **Firebase** — Auth + Firestore is the backend. Firestore's `snapshots()` streams are what give you "changes propagate live, no restart" for free — this is not something you build, it's the default behavior of a `StreamBuilder`/Bloc listening to a collection.
- **FastAPI (optional)** — only stood up when a requirement can't be satisfied by Firestore + security rules alone. See §6 for the exact test.
- **go_router** — typed routes optional (see §5).

The one thing worth internalizing up front: **Firestore already solves realtime propagation.** If your two apps are both just reading/writing the same collection, you don't need polling, you don't need a backend to "push" updates, and you don't need websockets — a Firestore listener does this natively. Reach for a backend only when the requirement is something *else* (see §6), not for realtime itself.

---



## 2. Monorepo layout

Two (or more) Flutter apps, one shared package, backend is a sibling folder that may or may not exist.

```text
your-project/
├── apps/
│   ├── staff_app/           ← Flutter app #1 (e.g. tablet/web, order-taking)
│   │   └── lib/
│   │       ├── features/
│   │       ├── core/        ← app-local only (theming, app-specific DI wiring)
│   │       └── main.dart
│   └── admin_app/           ← Flutter app #2 (e.g. phone, management)
│       └── lib/
│           ├── features/
│           ├── core/
│           └── main.dart
├── packages/
│   └── core/                 ← shared Dart package, imported by both apps
│       ├── lib/
│       │   ├── entities/      (plain Dart data classes — e.g. MenuItem)
│       │   ├── repositories/  (abstract contracts — e.g. MenuRepository)
│       │   ├── datasources/   (Firestore implementations of those contracts)
│       │   ├── failures/      (typed Failure classes for Result/Either)
│       │   └── blocs/         (optional: cross-app Blocs, e.g. shared MenuBloc
│       │                       if both apps display the same live menu)
│       └── pubspec.yaml
├── backend/                  ← optional, see §6. Absent if not needed.
│   └── app/
│       ├── api/
│       ├── services/
│       └── schemas/
├── firestore.rules
├── firestore.indexes.json
└── firebase.json
```

**Wiring** `packages/core` **in:** each app's `pubspec.yaml` gets a local path dependency:

```yaml
dependencies:
  core:
    path: ../../packages/core
```

Don't reach for `melos` unless you have 3+ packages or need cross-package versioning/scripts — for two apps and one shared package, plain path dependencies are less tooling to explain and less to go wrong. Add melos later if the monorepo grows.

**What goes in** `packages/core` **vs. app-local** `features/`**:** anything both apps touch — entities, repository contracts, Firestore datasources, failure types — lives in `core`. Anything one app alone cares about (a screen, a Bloc that's specific to that app's UX even if it reads the same entity) stays local to that app's `features/`. The test: *if I deleted app B, would this code become dead?* If yes, it's app-local. If no, it belongs in `core`.

---



## 3. Feature structure (per app)

Same three-layer split as victoria.md — presentation / domain / data — but domain contracts and data implementations for shared entities live in `packages/core`, and each app's `features/` folder is mostly `presentation/` plus anything genuinely app-specific:

```text
apps/staff_app/lib/features/menu/
└── presentation/
    ├── view/
    ├── bloc/            ← MenuBloc or MenuCubit — app-specific reaction to the shared repository
    └── widgets/
```

If a feature is 100% shared (same screen logic, same state shape, just different chrome), the Bloc/Cubit itself can live in `packages/core/lib/blocs/` and both apps' `view/` layers just consume it. Don't force this — only promote a Bloc to `core` once you're actually duplicating it, not preemptively.

---



## 4. State management: Bloc over Cubit

Default to **Bloc**, not Cubit, even for screens that feel simple — this is a deliberate change from "Cubit for simple screens," and the reasoning is worth being explicit about since it's the one place this doc diverges from the lighter-weight default:

- **Bloc forces an explicit event name.** `ToggleItemAvailability(itemId)` reads as an intent in the code and in tests; `cubit.toggleAvailability(itemId)` is just a method call. When two apps both mutate the same shared entity, having every mutation be a named, greppable event pays for itself once the event vocabulary is the thing both apps' logic has to agree on.
- **Cubit is still fine for pure local UI state that never becomes an event** — a search field's debounce state, a bottom sheet's expanded/collapsed flag, filter toggles that never touch a repository. If a class never talks to a repository, it doesn't need to be a Bloc.

Convention per bloc (unchanged from your usual pattern): one state class, an enum `status` (`initial | loading | success | failure`) plus `copyWith`, not a sealed class per status. Repository calls happen directly from the Bloc for simple CRUD/passthrough — no usecase layer unless you're combining multiple repositories or there's real business logic (e.g. "reject an order edit if the item just went sold-out").

---



## 5. Routing: go_router, typed routes optional

Set up once per app (each app has its own `GoRouter` instance and its own route tree — they're different apps, not different shells of one router), resolved through `get_it` rather than constructed inline in `main.dart`, per your usual convention.

**Typed routes** (`go_router_builder` + `@TypedGoRoute` annotations, code-generated `$appRoutes`) — optional, not required. Reach for it when:

- route arguments are non-trivial (more than an id string) and you want compile-time safety on them, or
- the app has enough routes that stringly-typed `context.go('/foo/$id')` calls are already causing typos.

Skip it when the app is small (a handful of routes, mostly id-based) — plain `GoRoute(path: ..., builder: ...)` with a typed helper function per route (e.g. `AppRoutes.menuDetail(String id) => '/menu/$id'`) gets you most of the safety without the build_runner step. This is a call to make per-app, not a monorepo-wide rule — a small phone-layout admin app and a denser tablet POS app can land on different sides of this.

---



## 6. Firebase as the backend, FastAPI as the escape hatch

**Default: no backend.** Both apps talk to Firestore directly through the datasource layer in `packages/core`. Firestore security rules (§7) are your only enforcement point. This satisfies "live updates without a restart" natively via `snapshots()` — no backend involved.

**Stand up FastAPI only when a requirement is one of these**, none of which Firestore + rules can do alone:

- calling a third-party service (payments, SMS, printing hardware integration) that needs a secret key that can't live on-device,
- a calculation or validation too complex/sensitive to trust to security-rules syntax or the client,
- something that must run on a schedule, independent of any client being open,
- enforcing a business rule where "the client could just not enforce this" is a real risk (e.g. money changing hands) rather than a cosmetic one (e.g. hiding a sold-out item).

If none of those apply to what you're building, don't create the `backend/` folder at all — an unused FastAPI scaffold is a liability in a scoped build (it's surface area to explain in a README as "why does this exist and do nothing"), not a neutral option. Add it the moment a real requirement needs it, following victoria.md §5's route → service → schema shape.

---



## 7. Firestore security rules — the baseline

Two roles worth distinguishing even at MVP scope: **staff/reader** (can read menu state, can write orders) and **admin/manager** (can write menu state). Enforce the read/write split by role, not by which app is asking — the client app is not a security boundary.

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isAdmin() {
      return isSignedIn() &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /menuItems/{itemId} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }

    match /orders/{orderId} {
      allow read, create: if isSignedIn();
      allow update, delete: if isAdmin();
    }

    match /users/{userId} {
      allow read: if isSignedIn() && request.auth.uid == userId;
      allow write: if false; // role assignment via admin SDK / console only, not client-writable
    }
  }
}
```

The load-bearing line is `allow write: if false` on `users/{userId}` — if clients could write their own role, the `isAdmin()` check is decorative. Role assignment has to happen out-of-band (Firebase console, custom claims via a trusted process), never through a client-writable field.

---



## 8. Error handling & DI — unchanged from your usual convention

- `Result`/`Either<Failure, T>` returned from repositories and datasources; typed `Failure` classes in `core/failures/` (shared) or `core/error/` (app-local, if the failure is app-specific); UI never sees a raw `FirebaseException`.
- `get_it` singleton, one `configureDependencies()` entrypoint per app's bootstrap. If a registration is identical across both apps (e.g. the `FirebaseFirestore.instance` singleton, the shared `MenuRepository` implementation), pull it into a `registerCoreDependencies(GetIt it)` function in `packages/core` that each app's `configureDependencies()` calls first, then layers app-specific registrations on top.

---



## 9. Why this shape (the deltas from victoria.md, specifically)

**Why** `packages/core` **instead of one app importing the other's** `lib/`**?** Neither app is a dependency of the other conceptually — they're peers that happen to share a domain. A third shared package makes that explicit and avoids one app's `pubspec.yaml` accidentally pulling in the other app's Flutter widget tree.

**Why Bloc-over-Cubit as the default here specifically, when your usual rule is "Cubit for simple screens"?** The usual rule optimizes for one app, one team, one place mutations happen. The moment two separate apps mutate the same shared state, the event name becomes a piece of shared vocabulary between codebases — worth the extra Bloc boilerplate. This is a narrow override for the multi-app case, not a change to your general default.

**Why is the backend optional rather than always-scaffolded?** In a time-boxed build, a backend that exists but does nothing is worse than no backend — it's something a reviewer has to ask "why is this here" about. Scaffold it exactly when a requirement forces it (§6), and say so in the README if you deliberately left it out.