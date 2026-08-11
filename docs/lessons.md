# Technical lessons from the cubic-dev-ai review cycles

Synthesized from two rounds of automated review (`cubic-dev-ai`) on this repo:
**PR #1** ("Restructure into multi-app monorepo" — 16 findings, all fixed in
[`585c13b`](https://github.com/jnnabugwu/pos_application/commit/585c13b822d3dfcd9a342aeeda54c1d5979d9ac8))
and **PR #2** ("Split menu management into manager_app, add order-taking to
pos_app" — 17 findings, fix pass in progress). These aren't a list of the
individual findings — that's in the PR review threads — this is the small set
of *recurring root causes* behind them, worth internalizing so the same shape
of bug doesn't get reintroduced somewhere else in the codebase.

## 1. A discarded `Either`/`Result` is a silent failure, not a safe default

Three separate instances, same root cause: a repository call returns
`Either<Failure, T>`, and the call site does `await repo.doThing();` and
throws the result away.

- PR #1: `AuthBloc._onSignOutRequested` called `_authRepository.signOut()`
  and unconditionally emitted `AuthState()` regardless of the result — a
  failed Firebase sign-out looked identical to a successful one; local state
  reset while Firebase stayed signed in.
- PR #1: `MenuBloc._onToggleAvailability` called `setAvailability(...)` and
  discarded the `Either` — a staff user tapping a switch they don't have
  permission to flip saw nothing happen and no error, because the
  `PermissionFailure` never reached anywhere that could show it.
- PR #2 (in progress): the same shape reappeared in `OrderBloc` and the menu
  form — checkout/edit calls that don't fold their result before deciding
  what the UI shows next.

**Why this keeps happening:** `Either<Failure, T>` (this codebase's whole
reason for using `dartz` instead of letting exceptions propagate — see
[architecture-decisions.md](./architecture-decisions.md)) only pays for
itself if every call site actually pattern-matches on it. Dart doesn't force
that the way a checked exception or a `try`/`catch` requirement would; an
unused `Either` compiles cleanly and looks identical to a handled one until
someone actually triggers the failure path in testing. **The type system
choice doesn't enforce the discipline it was chosen for — code review does.**
Fix in code review, but also: any new repository call site should be written
with `result.fold(onFailure, onSuccess)` as the default shape, not
`await result;` with a TODO to handle errors later.

## 2. Two sources of truth for the same piece of state will disagree eventually

- PR #1: `pos_app`'s router defaulted `initialLocation` to `/menu` while
  `AuthListenable.ready` started `false` — a cold, signed-out launch briefly
  built `MenuPage` and fired a Firestore read before the redirect logic had
  even run once. Fixed by starting on `/login` instead, so the redirect (not
  the initial route) is what decides where a resolved session actually goes.
- PR #2 (open): the same pattern recurred one layer over — `manager_app`'s
  `AuthListenable` (used for router redirects) and `AuthBloc` (used by
  `MenuPage` to decide whether to show admin controls) both independently
  track "who's signed in," and only one of them gets updated when a session
  is *restored* (vs. a fresh interactive sign-in). Net effect: an admin
  reopening the app reaches `/menu` correctly (the listenable resolved) but
  is shown the read-only staff view (the bloc never heard about it).

**The lesson:** when two objects both need to react to the same async source
of truth (here, `AuthRepository.authStateChanges()`), don't give them two
independent subscriptions that are each responsible for their own picture of
"current user." Either have one subscribe and the other derive from it, or
make the redirect/gating logic read from a single shared source
(`AuthBloc.state`, with the router listening to *that* instead of its own
parallel `AuthListenable`). Two listeners to the same stream is fine; two
independently-updated *copies of the resulting state* is where they drift.

## 3. A stream-backed Bloc dies quietly on its first error unless you plan for retry

`OrderBloc` subscribes to `watchMenu()` exactly once via `emit.forEach(...)`.
That's correct for the common case — Firestore's stream re-emits on every
change, so there's normally nothing to retry. But `emit.forEach`'s
subscription *ends* the moment the stream emits an error, and nothing
re-subscribes it. A transient failure (no network at launch) turns into a
permanently-broken screen: the UI shows a static error message with no way
forward except leaving the route entirely (which happens to work only
because it re-creates the `OrderBloc` from scratch).

**The lesson:** a stream that's expected to error under *normal* conditions
(a network blip, not just a programming bug) needs an explicit path back to
a working state — either the widget dispatches a retry event that
resubscribes, or the bloc itself resubscribes on error instead of letting
`emit.forEach` end the subscription. "The stream will just emit again" is
only true for data changes, not for terminal stream errors.

Related, smaller version of the same class of bug: PR #1's
`AuthListenable`'s `.listen(...)` call had no `onError` at all, so a failed
Firestore role lookup (inside `_resolveAppUser`) would have become an
unhandled exception instead of a recoverable state. Fixed by adding
`onError` that fails safe (`currentUser = null; ready = true;`) rather than
leaving `ready` stuck `false` forever or crashing.

## 4. Optimistic-vs-confirmed state has a double-tap race if you don't pick one

`MenuBloc._onToggleAvailability` computed the write target as `!item.available`
from `state.items` — which only updates once Firestore's snapshot listener
pushes the *confirmed* value back. A rapid double-tap reads the same stale
`available` for both taps, computes the same target twice, and the second
tap becomes a no-op — the switch visually fails to toggle back.

**The lesson:** once a UI shows a value that's driven by a round-trip (write
→ Firestore → snapshot listener → re-render), decide explicitly whether
interactions during that round-trip are optimistic (update local state
immediately, roll back on failure) or locked (disable the control until the
confirmed value arrives). The bug here was a third, unintentional option —
neither optimistic nor locked, just reading a value that was already stale
by the time the second tap landed. The fix applied an optimistic local
update with rollback-on-failure; `cart_panel.dart`'s in-progress PR #2 fix
(disabling mutations while a checkout write is in flight) is the "locked"
version of the same decision, appropriate there because checkout is a
one-shot action rather than a togglable switch.

## 5. Money and inventory need validation everywhere they can be written, not just in the form

The same "negative number gets silently persisted" bug showed up at three
different layers across PR #2, because each layer trusted the one "in front
of it" to have already validated:

- The manager app's create/edit form: `double.tryParse(...) ?? 0` — typing
  `-5` in the price field creates a real, negative-priced item; there's no
  inline validation error, it just saves.
- `FirestoreMenuDataSource.createItem`: takes `stockCount` as a plain `int`
  with no floor — even if every current UI caller behaves, the datasource
  itself doesn't stop a negative value from reaching Firestore.
- `firestore.rules`: the write rule for non-admin stock updates checked
  `stockCount >= 0` but not that it was *decreasing* — a signed-in staff
  account (not just the app) could, via a direct Firestore write, set stock
  to any non-negative number, including *increasing* inventory they have no
  business increasing.

**The lesson, which is really just this project's own stated security
philosophy** (see `starter.md` §7 / `firestore.rules`: *"the client app is
not a security boundary"*) **applied one layer deeper than we first applied
it:** validating in the Flutter form is a UX nicety, not a security or data-
integrity boundary — Firestore rules are the only layer that can't be
bypassed by a caller who isn't the app at all (a compromised session token,
a direct REST call, a different client entirely). Client-side and datasource
validation matter for good error messages and defense-in-depth, but the
rule that actually has to be correct is the one in `firestore.rules`, and it
needs to encode the *business* invariant (staff can decrease stock via
checkout, never increase it) — not just a type/shape check
(`stockCount is int && stockCount >= 0`), which only rules out garbage, not
abuse.

## 6. A full-document overwrite silently clobbers concurrent changes to other fields

`menu_item_form_page.dart`'s save path built a `MenuItem` from the full
in-memory `widget.item!` (the copy loaded when the edit screen opened) plus
the edited fields, then wrote the whole thing back. If stock or availability
changed on the server between "manager opens edit screen" and "manager taps
save" — e.g. a checkout decremented stock, or another admin toggled
availability — that concurrent change is silently overwritten by the stale
snapshot the form still had in memory.

**The lesson:** a form that opens with a read, lets a human sit on it for an
arbitrary amount of time, and then writes back is inherently exposed to this
unless the write is explicitly scoped to *only the fields the human actually
changed*, or the write is guarded by an optimistic-concurrency check (a
version/updated-at field compared in a transaction, reject if it moved).
"Round-trip the whole object" is the natural thing to reach for and is fine
for single-writer data; it's wrong the moment a second actor (a customer
checking out, another admin) can write the same document between your read
and your write.

## 7. A retried write needs a stable identity, or "at least once" becomes "more than once"

`firestore_order_datasource.dart`'s `createOrder` calls `_orders.doc()` (a
fresh auto-generated ID) on every invocation, while the calling bloc
preserves the cart and lets the user retry checkout on failure. If a write
actually succeeds on the server but the client never receives the
acknowledgement (a dropped response, not a dropped write — a real failure
mode over any network), the client believes it failed, the user retries, and
a second order gets created for a checkout that already happened once.

**The lesson:** any write that represents a real-world event that must
happen *at most once* (an order, a payment, anything money-shaped) needs an
idempotency key that's stable across retries of the *same logical attempt* —
generate the ID client-side once per checkout attempt and write to that same
document ID on retry, rather than letting "create a new document" be the
retry primitive. Auto-IDs are the right choice for the common CRUD case
(menu items) precisely because re-running "create" *should* make a second
one; checkout is the case where that assumption inverts.

## 8. Multi-platform config doesn't inherit across build variants or platforms — check each one

A cluster of PR #1 findings were all the same underlying gap: Flutter's
per-platform scaffolding generates *separate* config files per build variant
and per OS, and nothing keeps them in sync automatically:

- Android's debug/profile manifests declared `INTERNET`; the release
  manifest — generated as a separate file — didn't, so a release build would
  have shipped with no network access for Firestore/Auth at all.
- macOS ships with the App Sandbox on by default; neither
  `DebugProfile.entitlements` nor `Release.entitlements` granted
  `com.apple.security.network.client`, so every Firebase call would have
  been blocked by the sandbox regardless of how correct the Dart code was.
- `manager_app`'s `main.dart` calls
  `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`,
  but `flutterfire configure` was only run for the platforms actually being
  developed against — Linux/Windows have no entry in `currentPlatform`, so
  running the "prescribed" `flutter run` on either desktop target throws
  before the first frame renders.
- iOS's `pbxproj` had a real, personal `DEVELOPMENT_TEAM` hardcoded into all
  three build configs — works for the one developer whose machine has that
  team's signing certificate, breaks automatic signing for literally anyone
  else (including CI) checking the repo out.
- `manager_app`'s `google-services.json` (Android) contained *two* client
  blocks — its own, and a leftover copy of `pos_app`'s — because both were
  generated against the same Firebase project and the second one just got
  copied in rather than trimmed to the one package this app actually is.

**The lesson:** "the app builds and runs on my machine, for the platform I'm
actively testing" is not evidence that platform config is complete —
generated project files (`.pbxproj`, `.plist`, `.json`, manifests) fan out
per-platform and per-variant specifically so they *can* diverge, and nothing
in the normal `flutter run` loop exercises the variant/platform you aren't
currently pointed at. This is exactly the kind of file a human reviewer
tends to skim past (dense, generated, "probably fine") and where an
automated review earns its keep — every one of these was a real runtime
break, not a style nit, and none would show up in `flutter analyze` or a
unit test.

## 9. `registerLazySingleton` only defers if the *closure* defers, not just the registration call

```dart
// Looks lazy, isn't:
final firestoreInstance = firestore ?? FirebaseFirestore.instance; // ← runs NOW
it.registerLazySingleton<FirebaseFirestore>(() => firestoreInstance);

// Actually lazy:
it.registerLazySingleton<FirebaseFirestore>(
  () => firestore ?? FirebaseFirestore.instance, // ← runs on first resolve
);
```

`registerCoreDependencies` evaluated `FirebaseFirestore.instance` *before*
handing a value to `registerLazySingleton`, which defeats the entire point of
"lazy" — the access happens at registration time regardless. In this repo's
actual bootstrap order it was harmless (`Firebase.initializeApp()` always
ran first), but it meant `registerCoreDependencies` would throw immediately
for any caller that didn't guarantee that ordering — a unit test of an app's
`configureDependencies()`, for instance — defeating the one property
(deferred creation) the function's own naming promised.

**The lesson:** "lazy" has to mean the side-effecting call is textually
*inside* the factory closure, not just that the factory closure exists.
Capturing a value computed outside the closure and returning that captured
value from the closure is not lazy, no matter what the registration API is
called.

## 10. Dead code shows up when two implementations of the same capability get built in parallel

PR #2: `MenuBloc` grew a full write-event vocabulary
(`CreateItemRequested`/`UpdateItemRequested`/`DeleteItemRequested`) that
nothing in the app ever dispatches, because `MenuItemFormPage` was written
to call `MenuRepository` directly instead (so it could `await` the result
inline and show a validation error) — the two write paths were built
independently and only one of them is actually wired to a screen. Same
underlying shape, smaller instance: `packages/core`'s `Order.fromMap` was
written speculatively for a read path that doesn't exist yet — checkout only
ever *creates* orders; nothing reads one back.

**The lesson:** this is worth flagging specifically because it's the mirror
image of a call this project made deliberately earlier —
[architecture-decisions.md](./architecture-decisions.md) and the original
planning notes for `packages/core` explicitly reasoned about *not* giving
`MenuBloc` a shared write vocabulary, on exactly this basis (nothing else
would dispatch it, so it'd be dead weight). That reasoning was sound but got
bypassed in practice once a second implementation (the form calling the
repository directly) was built without checking back against it. **A design
decision written down once doesn't enforce itself on the next file that
touches the same concern** — worth a quick "does this duplicate a path we
already have" check specifically when adding a new event/handler to an
existing Bloc, not just when starting a new feature from scratch.

## 11. `await Future.delayed(Duration.zero)` in a test is a race, not a guarantee — and a `verifyNever` on an empty list can pass for the wrong reason

`menu_bloc_test.dart` used `await Future<void>.delayed(Duration.zero)` to
"wait" for an async `watchMenu()` stream to populate `state.items` before
dispatching a follow-up event. Two independent problems in one pattern:

- It's coupled to microtask/timer interleaving rather than an actual
  observable signal that the stream settled — flaky by construction, not by
  bad luck.
- The test asserting `verifyNever(setAvailability)` for an unknown item ID
  passed regardless of whether the guard clause worked, because if the
  delay wasn't long enough, `state.items` was *also* still empty — "no item
  found" and "guard correctly rejected an unknown ID" are indistinguishable
  results, so the test could pass while proving nothing about the code it
  was named for.

**The lesson:** a test that passes by accident is worse than one that fails
by accident — it removes the safety net silently instead of loudly. When a
test needs to wait for async state to settle, wait on the actual signal
(the bloc's own state stream, `bloc_test`'s built-in wait/skip handling, an
`expectLater`/`emitsInOrder` against the thing that's actually changing) —
not a fixed delay that happens to usually be long enough on a fast CI
runner. And when a "verify X was never called" assertion is the whole point
of a test, make sure the setup actually reaches the branch that *could* have
called it, not a state where "never called" is true for an unrelated reason.

## 12. A rendered widget test only proves the state it was pumped in — not the path that reaches it

`menu_page_test.dart` (PR #1) rendered `MenuPage` while the bloc was still in
its default `MenuStatus.initial` state and asserted the loading spinner
showed — passing, but never dispatching `WatchMenuStarted`, which is the
only thing that actually starts a menu load in the real app (the router
fires it). The test's name implied it covered "before the menu loads," but
it couldn't have caught a regression in the loading→success transition or in
`_onWatchMenuStarted` itself, because it never exercised either.

**The lesson:** a widget test that constructs a bloc and pumps it in a
specific state is testing "does this state render correctly," which is
useful but is a different (weaker) claim than "does the real trigger path
reach this state correctly." If the test's name or intent implies the
latter, the setup needs to dispatch the real event (with the repository
mock stubbed to return what that event needs), not construct the target
state directly and skip the path that's supposed to produce it.

## Summary table

| # | Pattern | PR | Status |
|---|---|---|---|
| 1 | Discarded `Either` results | #1, #2 | Fixed in #1 (`585c13b`); recurring in #2 |
| 2 | Two independent copies of auth state | #1, #2 | Fixed in #1; open in #2 |
| 3 | Stream error ends a one-shot subscription with no retry | #1, #2 | Fixed in #1 (`onError`); open in #2 (`OrderBloc` retry) |
| 4 | Optimistic-vs-locked write races | #1, #2 | Fixed in #1 (optimistic); addressed differently in #2 (lock during checkout) |
| 5 | Money/inventory validated in only one layer | #2 | Open (form, datasource, and rules all need it) |
| 6 | Full-document overwrite clobbers concurrent writes | #2 | Open |
| 7 | Retryable write without an idempotency key | #2 | Open |
| 8 | Per-platform config doesn't inherit | #1 | Fixed in `585c13b` (bundle-id placeholder deliberately left, see commit message) |
| 9 | `registerLazySingleton` capturing outside the closure | #1 | Fixed in `585c13b` |
| 10 | Parallel/duplicate implementations, one path dead | #2 | Open |
| 11 | Timing-based test waits + vacuous `verifyNever` | #1 | Fixed in `585c13b` |
| 12 | Widget test skips the real trigger path | #1 | Fixed in `585c13b` |
