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
