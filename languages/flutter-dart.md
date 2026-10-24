# Dart / Flutter

**Scope:** apply this file only when the task involves Dart or Flutter (`*.dart`, `pubspec.yaml`, or `fvm`/`flutter`/`dart`/`melos` commands). Otherwise ignore it completely. It adds to `AGENTS.md` and doesn't replace it. Where a repo's own established pattern differs, follow the repo and point out the difference.

## Tooling
- Always run Dart and Flutter through FVM: `fvm flutter …`, `fvm dart …`. Never call bare `flutter` or `dart`.
- Monorepos use melos or pub workspaces. Use the repo's scripts (e.g. `melos run generate`).
- Never edit `pubspec_overrides.yaml`. Put overrides in `pubspec.yaml` `dependency_overrides` so they show in git. You may delete stale *generated* `pubspec_overrides.yaml` files that break workspace resolution.
- Lint with `very_good_analysis`. No `// ignore:` without a justifying comment. Fix only errors.
- Never read or edit generated files (`*.g.dart`, `*.freezed.dart`, `*.mapper.dart`, `*.gr.dart`, `*.config.dart`, `*.pb*.dart`, `*.gen.dart`). Read the source and regenerate.
- The `build_runner` watcher (freezed, json_serializable, injectable) should always be running. If it isn't, ask me to start it. If you're working unsupervised and it has died, run it yourself.
- Never run the app. See `AGENTS.md`.

## Language
- Use Dart 3: exhaustive `switch` expressions, sealed classes, records, patterns, and dot-shorthand enum cases (`.venue`).
- Never type a field or param as `num`. Use `int` or `double`.
- Models we own get getters on the class or enum. Models we don't own (package or server types) get extensions.
- Don't add a local alias variable just to null-check a field.
- Use `const` constructors wherever possible.
- `///` dartdoc on public APIs, with `{@template}`/`{@macro}` for reuse. No obvious inline comments.

## Project structure (life-event-planner pattern)
```
lib/
  app/
    app.dart                  # barrel
    core/
      bloc/                   # app-wide blocs/cubits (e.g. auth_cubit.dart)
      dependencies/
        dependencies.dart     # getIt + @InjectableInit configureDependencies()
        modules/              # @module classes for 3rd-party/async deps
      service/
    extensions/
    navigation/               # app_router.dart, routes.dart
    widgets/                  # app-wide widgets
  data/                       # shared data sources/stores (database, images, ...)
  design_system/
  features/
    <feature>/
      <feature>.dart          # feature barrel (the only import used for this feature)
      bloc/      bloc.dart, <x>_bloc.dart, <x>_event.dart, <x>_state.dart
      models/    models.dart, ...
      repository/ repository.dart, <x>_repository.dart
      view/      view.dart, <x>_page.dart, <x>_view.dart
      widgets/   widgets.dart, ...   # feature-only widgets
  l10n/
  gen/
```
- Always import through barrels. Inside a feature, import its top-level barrel (`features/<f>/<f>.dart`), not siblings or sub-barrels.
- Layers go data → repository → bloc → presentation. Data flows up only. No layer imports one above it, and repositories never depend on other repositories.
- Views never call repositories or services. Every user action flows view → bloc event → repository. Only blocs and the composition root touch repositories.
- Feature-only widgets go in the feature's `widgets/`. App-wide widgets go in `app/widgets/`.
- Every screen is a page/view pair. `XPage` holds `static const path` and the `BlocProvider`. `XView` is the content. Keep the pair even when there's no bloc yet.

## Dependency injection (get_it + injectable)
- Everything is built by get_it/injectable: repositories, services, the router, third-party objects, and blocs. Never construct a dependency by hand. Take it as a constructor parameter and let injectable order the graph.
- Repositories, services, stores, and the router are `@singleton` (or `@lazySingleton`). Third-party and async objects come from `@module` classes (`@preResolve` for futures).
- Page-scoped blocs and cubits are the only `@injectable` (factory) classes. They get a new instance per request, with per-instance values via `@factoryParam`.
- A page provides its bloc with `BlocProvider`, so it is found by context and closed with the page:
  ```dart
  return BlocProvider(
    create: (_) => getIt<PlansBloc>()..add(const PlansEvent.started()),
    child: const PlansView(),
  );
  ```
  Call `getIt<SomeBloc>()` only inside `BlocProvider.create`, since anywhere else it creates an orphan that nothing closes. Children read it with `context.read`/`BlocSelector`.
- **Accepted exception: app-wide blocs.** A bloc or cubit that lives as long as the app (e.g. `AuthCubit`, which the router also needs) is `@singleton`, not `@injectable`. Inject it by constructor into non-widget code (e.g. `AppRouter`), read it in widgets with `getIt<T>()`, and pass it as `bloc:` to `BlocBuilder`/`BlocSelector`/`BlocListener`. Never put it in a `BlocProvider`, and add no `isClosed` guards or close code.
- `BlocProvider` is the only provider API. No `RepositoryProvider`, `MultiProvider`, or provider-held services.

## State management
- Bloc and Cubit are both fine. Pick whichever fits the feature.
- Use one event handler with an exhaustive `switch` over the events, so every event is mapped.
- Wrap async handlers in try/catch: emit loading, then success or failure. Log with `log()` from `dart:developer`, never `print()`. If the repo has an error-reporting pipeline (e.g. `addError` + analytics), use it.
- Every loading state must reach a terminal state. A swallowed error must never strand a spinner.
- Prefer `BlocSelector` over `BlocBuilder`. Select several fields with a record. Use `BlocListener` for side effects.
- Use `bloc_concurrency` transformers where concurrency matters (`droppable()` for user mutations, `sequential()` for ordered work, `concurrent()` for never-ending stream handlers).
- Use HydratedBloc for persisted state, and follow the persisted-state rule in `AGENTS.md`. Version the state and route by `version` in `fromJson`. Keep freezed `fromJson` arrow-bodied and delegate the routing to a factory.

## Models & serialization
- freezed, dart_mappable, and json_serializable are all fine. Match what the repo already uses. Never hand-write `copyWith`, `==`, or `props`.
- Use `@JsonSerializable(fieldRename: FieldRename.snake)` only when the API really is snake_case. Check the backend first.
- Use DTOs only when the API shape doesn't map cleanly to the domain model.

## Data layer
- API clients own the wire format. They take typed request objects and return raw `Response<dynamic>`. Never put `Map<String, dynamic>` in API signatures.
- Repositories parse (`mapJson()`/`mapJsonList()`), map, and cache. Caching never goes in a bloc. Throw typed, documented exceptions (`/// Throws [X] when …`).

## Navigation
- Use the repo's router. For new apps, use typed `GoRouteData` routes in `lib/app/navigation/routes.dart`, each returning a `NoTransitionPage` from `buildPage`. In repos on `auto_route`, every routable screen is a `@RoutePage()` page with typed navigation.

## UI
- Prefer widget classes to builder methods or static widget-returning methods. Keep a single-use widget in the same file (a private class) unless the file is over ~250 lines. Move a widget to a shared file only when more than one caller uses it. Inline a widget that only wraps another widget.
- Bottom sheets and dialogs each get their own widget file with `static Future<T?> show(BuildContext)`. Never build them inline in a view.
- Text styles come from theme roles (`textTheme.displaySmall`). Don't `copyWith` sizes, weights, or colors at call sites. Add missing roles to the app theme.
- Design tokens: declare reused tokens once at the top of the build method, use single-use tokens inline, and stay consistent within a file.
- Responsive UI uses `context.layout`, `context.isMobile`, `context.isTablet`, and `context.isDesktop` (or `context.layout >= LayoutData.medium`).
- Make apps work on every platform they ship to (e.g. Android, iOS, Web). Check each plugin's platform support before adopting it.
- Accessibility (WCAG 2.2 AA): semantic labels on images, 48dp tap targets (no bare `GestureDetector` for actions), `Semantics(header: true)` on headings, live-region announcements for async changes, contrast of 4.5:1 for text and 3:1 for UI, no fixed-height boxes around `Text`, reduce-motion gating, drag alternatives, and never block paste in OTP or password fields.

## Tests (only when I ask for them)
- `mocktail`, never mockito. Private mocks per file: `class _MockX extends Mock implements X {}`.
- `blocTest` for blocs. Create the bloc as `late` in `setUp` and use `build: () => bloc`, with no `buildBloc()` helper.
- `group(TypeName, …)` with the bare type. All `setUp`/`tearDown` go inside groups, using `late` + `setUp`, not top-level finals.
- Matchers only (`equals`, `isEmpty`, `isNull`, `isTrue`). Prefer `isA<State>().having(...)` to matching a whole state.
- Use the repo's `pumpApp` helper. Mirror `lib/` paths. Tests must pass with `--test-randomize-ordering-seed=random`.
- Call `initHydratedStorage()` in setup when testing a `HydratedBloc`.
