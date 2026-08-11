# Architecture decisions

Tradeoff write-ups for calls made during the build that aren't obvious from
reading the code, kept here instead of scattered in commit messages. This
file grows as later phases add entries (order persistence design, the
MenuBloc read/write split, platform choice).

## Model layer collapsed into entities, not a separate `data/models/` layer

**The decision:** `MenuItem` and `AppUser` (`packages/core/lib/entities/`)
carry their own `fromMap`/`toMap` methods directly, rather than each having a
separate `MenuItemModel`/`AppUserModel` class in a `data/models/` folder the
way a stricter three-layer clean-architecture split would do it.

**Why:** the usual reason to keep a model separate from its entity is to stop
the domain layer from knowing anything about the wire format — valuable when
an entity is fed by more than one data source with diverging shapes (e.g.
Firestore *and* a REST API), or when the wire format is messy enough that you
don't want it touching the domain type directly. Neither pressure exists
here: there's exactly one data source (Firestore) per entity, for the
lifetime of this project.

**How the decoupling is kept anyway:** `fromMap`/`toMap` work on a plain
`Map<String, dynamic>` with real `DateTime` values, not a Firestore
`DocumentSnapshot` and not a `Timestamp`. The entity files have zero
`cloud_firestore` import. The one place that boundary is actually crossed —
converting a Firestore `Timestamp` to a `DateTime` on read — lives in
`FirestoreMenuDataSource._fromSnapshot` (`packages/core/lib/datasources/firestore_menu_datasource.dart`),
not in the entity. So the entity still can't accidentally depend on the SDK;
there's just no second class duplicating its field list to enforce that.

**When this would need to change:** if a second data source is ever added
for the same entity (e.g. importing a menu from a POS vendor's CSV/REST
export) with a shape that doesn't line up with Firestore's, split the model
back out then — `fromMap`/`toMap` on the entity would become `fromFirestore`
on a new model class, and the entity goes back to being pure data.

## Seeding Firestore data without a service-account key

**The decision:** `scripts/seed_menu_items.js` (used to seed random
`menuItems` docs for local development/demo) authenticates by reusing the
existing `firebase login` session — via `firebase-tools`' own internal
`auth.getGlobalDefaultAccount()` / `auth.getAccessToken()` — rather than a
downloaded service-account JSON key.

**Why:** `firebase-tools`' CLI has no generic "write a document" command
(`firebase firestore:*` only covers delete/bulkdelete/indexes/locations/
databases/backups — see `firebase firestore --help`), so any scripted write
has to go through either the Firestore REST API or the Admin SDK directly,
both of which normally expect a service-account key. Generating one
(Firebase Console → Project Settings → Service Accounts) creates a new,
fairly broad, long-lived credential file that then has to be stored and kept
out of version control — a lot of standing risk for a one-off seeding
script. Reusing the CLI's own already-granted OAuth login instead means: no
new credential file is created, the access token is scoped
(`cloud-platform`) and short-lived, and it's limited to whatever the signed-in
account (the developer's own `firebase login` account) can already do — the same trust level
already implicitly granted by having `firebase deploy` work on this machine.

**How it works:** `firebase-tools` is installed locally into `scripts/`
(`npm install firebase-tools --no-save`, gitignored) purely so its internal
`lib/auth.js`/`lib/scopes.js` modules can be required directly — the same
modules the CLI itself uses before every authenticated command. The account
info comes from `~/.config/configstore/firebase-tools.json` (where `firebase
login` stores it); `getAccessToken()` exchanges the stored refresh token for
a fresh access token, which is then sent as a normal `Authorization: Bearer`
header to the Firestore REST API (`POST .../documents/menuItems`) to create
each doc, encoding fields in Firestore's typed JSON format (`stringValue`,
`integerValue`, `booleanValue`, `timestampValue`) to match exactly what
`MenuItem.fromMap` expects on read.

**When this would need to change:** for anything beyond occasional local
seeding — a script that needs to run in CI, on a schedule, or without a
developer's own `firebase login` session available — switch to a real
service-account key (or Workload Identity Federation for CI) rather than
this technique; it depends on `firebase-tools`' internal module layout,
which isn't a public API and could change between versions.

## Remaining concurrency gaps: client-only idempotency, no reservation step

**The assumption this build makes:** one instance of `pos_app` and one
instance of `manager_app` running at a time (one POS terminal, one manager
device) — not multiple staff-facing terminals or multiple managers editing
concurrently. Firestore transactions still make the pieces that *are*
implemented safe under that assumption (checkout's stock decrement, and
checkout's own retry-idempotency below); what's deliberately not built is
the harder distributed-systems layer that would make this safe with
multiple concurrent writers.

**What's already handled (client + Firestore transaction only, no
backend):**

- Two checkouts decrementing the same item's stock race safely — the
  decrement happens inside a `runTransaction` in
  `FirestoreOrderDataSource.createOrder` (`packages/core/lib/datasources/firestore_order_datasource.dart`).
- Retrying *the same* checkout attempt (e.g. the write committed but the
  client never saw the ack, so the user taps Checkout again) doesn't create
  a duplicate order or double-decrement stock — `OrderBloc` generates a
  request id once per attempt and reuses it across retries; the datasource
  writes to `orders/{requestId}` and treats an already-existing doc as "already
  applied, hand back what's there" rather than re-running the decrement.

**What a real backend would add, if multiple instances were in play:**

- **Durable idempotency, not just in-memory.** `OrderBloc._checkoutRequestId`
  lives in memory — if the app crashes mid-checkout and restarts, that id is
  gone, and there's no way for the client to ask "did my last attempt
  actually commit?" other than the order simply not appearing. A backend
  with a durable request log (or a client-persisted pending-request id
  written to disk before the network call) would close that gap.
- **Restock vs. concurrent sale on the same item.** `MenuItemFormPage`'s
  restock flow (`MenuRepository.updateItem`) writes an absolute
  `stockCount` typed by a manager; if a checkout decrements that same
  item's stock between when the form loaded and when the manager saves, the
  save overwrites the sale's decrement with the (now-stale) typed number.
  This build already stops `updateItem` from touching `available` for
  exactly this reason (see the datasource's doc comment), but doesn't
  extend the same treatment to `stockCount`, since restocking is this
  form's actual job — a correct fix is a delta-based "adjust stock by ±N"
  write (or an optimistic-concurrency version check) rather than
  "set stock to N", which is a small backend endpoint or a Cloud Function,
  not something Firestore security rules alone can express well.
- **Multiple POS terminals selling the same running low item.** Handled
  correctly today by the transaction (no oversell past what the transaction
  sees at commit time), but there's no reservation/hold step — two staff
  members can both have the last unit in their cart simultaneously and only
  find out one lost at checkout time. A backend with a short-lived
  reservation (or a queue that serializes checkouts) would give the second
  staff member that feedback before they finish building the order, not
  after.
