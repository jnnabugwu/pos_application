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
account (`jordannnabugwu@gmail.com`) can already do — the same trust level
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
