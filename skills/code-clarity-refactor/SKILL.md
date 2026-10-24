---
name: code-clarity-refactor
description: Refactor a file or feature so a developer who has never seen it understands the intent and flow from the code alone. Marks unclear spots with clarity TODOs, lets the user prune them, proposes code-level fixes (never doc fixes), then applies them one at a time with an explanation for each. Manual only - run only when the user types /code-clarity-refactor or names this skill.
disable-model-invocation: true
metadata:
  short-description: One-change-at-a-time clarity refactor
  author: Jacob Blankenship
---

# Code Clarity Refactor

The goal: someone reads the code once and the intent and flow are obvious. Clarity lives in the code, not in docs. If a line needs a comment or doc to be understood, the code isn't clear yet — fix the code.

Never propose doc or comment changes as a clarity fix. Docs come later and only for what good code can't say.

---

## Process

### 1. Read everything first

Read the target file in full, plus the models, extensions, and call sites it depends on. You need to know where each rule's data lives before suggesting where the rule should live.

### 2. Mark every unclear spot with a TODO

Insert `// TODO(clarity): <what a first-time reader would trip on>` directly above each spot. Be generous; the user prunes. Look for:

- **Negations and implicit conditions** whose meaning depends on knowing the rest of the code (`precision != .park` meaning "venue or land").
- **Rules about a model's data computed far from the model** (a service checking a store's flags and switching on its geometry type).
- **Dual-purpose values** (one enum value meaning both "permission OK" and "action allowed").
- **Decisions hidden in the wrong method** (an "is enforcement on?" short-circuit buried inside the measuring helper).
- **Names that hide behavior** (`_getPosition` that silently drops inaccurate readings).
- **Separate parameters that must stay in sync** (passing `storeId` and `landId` pulled from different places instead of the store).
- **Values computed but only sometimes used**, which read as "always considered".
- **Silent fallbacks** (`?? false`, `?? null`) that change meaning.

Do not write TODOs that only complain about docs.

Then stop and let the user remove the ones they think are clear.

### 3. Propose code fixes for the remaining TODOs

For each remaining TODO, describe the code change in prose (no code blocks — this is ideation) and say how the call site will read afterward. Fixes come from the precedents below. Recommend one option per TODO. If a fix needs a new type, first check whether the platform or a dependency already provides one and say so.

### 4. Apply one change at a time

Before each edit, explain in one short paragraph what changes and why it reads better. Then make that edit only. The user accepts or rejects each one; a rejection with a comment is feedback, not a stop — adjust and continue.

- When the user gives a naming correction, apply it everywhere it appears.
- When the user asks a direct question in a rejection, answer it directly first (lead with yes/no), then continue.
- After the last change, run the project's analyzer (`fvm dart analyze` for Dart) and fix errors only.

---

## Precedents

These are the standard. Reach for them first.

### Rules about a model's own data live in a named getter on that model

Put "is this usable / which value applies" logic in a getter on the model (or an extension on it), so call sites read as intent.

```dart
extension StoreExtension on Store {
  /// The venue geofence to check, `null` when it is disabled or missing.
  GeofenceTarget? get venueGeofenceTarget {
    if (!storeGeofenceEnabled) return null;

    final geofence = switch (storeGeofenceType) {
      .polygon => storeGeofence,
      .radius => storeRadiusGeofence,
    };
    return geofence == null ? null : GeofenceTarget(.venue, geofence);
  }
}
```

### Decisions are a `switch` on the caller's intent, each arm reading as its goal

Use `??` chains so the fallback order is visible. The switch stays exhaustive, so a new case is a compile error, not a silent fallthrough.

```dart
final target = switch (preferredPrecision) {
  .venue =>
    store.venueGeofenceTarget ??
        land?.landGeofenceTarget ??
        parkGeofenceTarget,
  .land => land?.landGeofenceTarget ?? parkGeofenceTarget,
  .park => parkGeofenceTarget,
};
```

### Name the condition instead of explaining it

Replace a negation plus a comment with a getter whose name is the reason, built from an explicit `switch`:

```dart
bool get isSharedLandResult => switch (precision) {
  .venue => false,
  .land || .park => true,
};
// call site: if (target.isSharedLandResult) { ... }
```

Ask the object for what you need (`target.blockedStatus`) rather than reaching through it (`target.precision.blockedStatus`).

### Separate meanings get separate types

If one value is overloaded (e.g. `GeofenceStatus.allowed` returned by a permission check to mean "access OK"), give the concept its own small enum and map to the shared type with a getter on it:

```dart
enum LocationAccess {
  granted,
  promptRequired,
  settingsRequired;

  GeofenceStatus get geofenceStatus => switch (this) {
    .granted => .allowed,
    .promptRequired => .permissionPromptRequired,
    .settingsRequired => .permissionRequired,
  };
}
// call site: if (access != .granted) return access.geofenceStatus;
```

### Main decisions live in the main flow

The public method should read top to bottom as the whole story (load → pick → measure if enforced → share → notify). Helpers do one thing; they don't secretly decide whether to do it.

### Names state hidden behavior

If a function filters, caps, or can return `null` for a reason, the name says so (`_getAccuratePosition`).

### Pass the object, not pieces of it

`result.statusFor(store)` instead of `statusFor(storeId: ..., landId: ...)` collected from different places.

---

## Style rules

- Full, specific names (`landGeofenceTarget`, not `landTarget`).
- Never use "resolve" / "resolver" / "resolved" in names.
- Prefer dot shorthand for enum values where the type is inferable (`.allowed`).
- Keep logic inline by default. Don't extract single-use helpers on your own initiative; extraction is the user's call.
- Don't write new tests (see `AGENTS.md`).
- Don't stage, commit, or push unless asked.
- In manual/ask mode, make each change through the normal reviewable edit flow (no sed or scripted edits). See `AGENTS.md`.
