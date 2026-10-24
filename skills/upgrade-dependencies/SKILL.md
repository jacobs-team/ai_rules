---
name: upgrade-dependencies
description: Upgrade the Flutter SDK and all dependencies (single package or melos/pub workspace) to their latest compatible versions, apply migration guides for upgraded packages, bring the native Android/iOS projects up to the new SDK's template, bump GitHub Actions if present, then fix analyzer errors. Manual only - run only when the user types /upgrade-dependencies or names this skill.
disable-model-invocation: true
metadata:
  short-description: Flutter SDK + dependency + native + CI upgrade
  author: Jacob Blankenship
---

# Upgrade the Flutter SDK and Dependencies

Bump the pinned Flutter SDK to the latest stable, upgrade every package to its latest possible version, migrate the code for breaking changes, bring the native Android/iOS projects up to what the new SDK and plugins expect, and leave the analyzer at zero errors. Use `fvm flutter` / `fvm dart` for all CLI commands. Don't write or run tests (see `AGENTS.md`).

## Step 0: Detect the repo shape

- **Single package:** one `pubspec.yaml` and one `pubspec.lock` at the root.
- **Pub workspace / melos monorepo:** the root `pubspec.yaml` has a `workspace:` list (or the repo has `melos.yaml` or a `melos:` section). List every member package. Workspace members share **one** root `pubspec.lock`. Older melos setups without `workspace:` have a lock per package, so snapshot each one.
- **The app package(s):** any package with `android/` and `ios/` folders (the root, or e.g. `<app>_flutter/`). The native steps run inside each app package.
- **Don't use `melos run upgrade`** or `pub upgrade --major-versions`. They let the solver settle below the latest versions, and this skill replaces them.
- **Stale generated `pubspec_overrides.yaml`** files (from old `melos bs`) that break workspace resolution may be deleted. Never edit them.

## Step 1: Snapshot the current state

Copy every `pubspec.lock` to `pubspec.lock.bak` next to it, so the changes can be diffed later. Use a cross-platform copy (the editor, `cp` on macOS, `Copy-Item` on Windows).

Note the current Flutter version in `.fvmrc` (the `flutter` field). If CI reads this file (e.g. `jq -r .flutter .fvmrc`), the upgrade must update this same file.

## Step 2: Upgrade the Flutter SDK

1. Find the latest **stable** Flutter version with `fvm releases` or https://docs.flutter.dev/release/archive. Stay on stable; never move to beta or master.
2. Set `flutter` in `.fvmrc` to that exact version: a pinned version string, not `"stable"`.
3. Install and select it: `fvm install`, `fvm use <version>`, `fvm flutter --version`.
4. Check that every package's `environment:` SDK constraint still admits the new Dart SDK. Raise lower bounds only if a dependency migration requires it.
5. If the SDK bump alone breaks `fvm flutter analyze`, treat those failures like the dependency migrations in Step 5 and base every fix on the Flutter release notes and breaking-change docs.

## Step 3: Upgrade dependencies to their latest versions

Pin everything to latest explicitly and downgrade only what conflicts:

1. From the repo root, get the latest published version of every direct dependency with `fvm dart pub outdated --json` (in a workspace this reports every member). Use each package's `latest` field.
2. In **every** pubspec (the root and every member), set each direct dependency in `dependencies` and `dev_dependencies` to `^<latest>`. Skip SDK-sourced entries (`flutter`, `flutter_localizations`, `flutter_test`, `flutter_web_plugins`) and path or workspace dependencies.
3. Resolve from the repo root: `fvm flutter pub get`.
4. If resolution fails, read the solver's conflict output, find the incompatibility, and downgrade the **minimal set** of packages needed. Prefer downgrading the package that blocks the fewest others, and step down only as far as the solver requires. Repeat until it resolves. Record every downgrade and its reason. Never force a version past the Dart/Flutter SDK constraint.
5. Upgrade the remaining transitive dependencies: `fvm flutter pub upgrade`.

Finally, run `fvm dart pub outdated` and report every package still behind its latest version and what is blocking it (SDK constraint, peer dependency, discontinued, etc.). Don't force-resolve these.

## Step 4: List upgraded packages

Diff each `pubspec.lock.bak` against the new lock file and build a table of every changed package: name, old version, new version, major/minor/patch, and, in a workspace, which member package(s) depend on it directly. Delete the `.bak` files once the table is done.

## Step 5: Apply migrations

For each **direct** dependency that changed (in any package):

1. Fetch its changelog at `https://pub.dev/packages/<package>/changelog`. For major bumps, also check the README or repo for a dedicated migration guide.
2. Read every entry between the old and new versions and note breaking changes, deprecations, and renamed or removed APIs.
3. Also note **native requirement changes**: a raised Android `minSdk`/`compileSdk`, new Kotlin/AGP minimums, a raised iOS deployment target, or Swift Package Manager/CocoaPods changes. Carry these into Step 6.
4. Search the codebase (every package) for the affected APIs and apply the required changes, following `AGENTS.md` and the repo's own instructions.

Don't guess at API changes. Base every change on the changelog or migration guide. If neither exists, read the package's README and API docs first. Never invent an API shape from memory.

Transitive bumps need no migration unless the analyzer reports errors from them.

Backend packages in the workspace (e.g. `dart_frog`, `drift`, `supabase`, JWT/bcrypt) follow the same changelog-driven process. If `drift` changed, check schema and migration API changes carefully: migration code must still compile.

If codegen packages changed (`freezed`, `json_serializable`, `injectable_generator`, `build_runner`, `flutter_gen_runner`, `drift_dev`, `dart_mappable_builder`, ...), regenerate everywhere: the repo's melos script (e.g. `melos run build`/`generate`) or `fvm dart run build_runner build --delete-conflicting-outputs` in each package that has codegen.

## Step 6: Bring the native projects up to date

The Android and iOS projects in each app package go stale independently of the pubspecs: Gradle, AGP, Kotlin, JVM targets, and iOS deployment targets drift behind what the new SDK and plugins expect.

1. Generate a pristine reference app with the new SDK in a temp/scratch directory outside the repo:
   `fvm flutter create --project-name ref_app --platforms android,ios,web ref_app`
2. In each app package, diff these files against the reference and adopt the reference's tooling versions. Never downgrade a value the project already pins higher, and keep project-specific config (flavors, `applicationId`/bundle IDs, signing, ProGuard, manifest entries, icons):
   - `android/gradle/wrapper/gradle-wrapper.properties`: the Gradle `distributionUrl`
   - `android/settings.gradle(.kts)`: AGP (`com.android.application`) and Kotlin (`org.jetbrains.kotlin.android`) plugin versions
   - `android/app/build.gradle(.kts)` and `android/build.gradle(.kts)`: `compileSdk`, `minSdk`, `targetSdk`, `ndkVersion`, and the Java/Kotlin JVM target
   - `android/gradle.properties`: JVM args and AndroidX flags
   - `ios/Flutter/AppFrameworkInfo.plist`: `MinimumOSVersion` (newer templates may omit it)
   - `ios/Runner.xcodeproj/project.pbxproj`: every `IPHONEOS_DEPLOYMENT_TARGET`
   - `ios/Podfile`: the `platform :ios` version (only if there's a Podfile)
3. Apply the native requirements collected in Step 5. When a plugin needs more than the fresh template (e.g. a higher `minSdk`), raise the project to the plugin's requirement.
4. For the SDK jump itself, check https://docs.flutter.dev/release/breaking-changes for Android/iOS template migrations between the old and new versions, and apply any that affect these files.
5. Prove Android builds with the new toolchain (file diffs alone don't catch Gradle incompatibilities). From the app package, run `fvm flutter build apk --debug`, adding `--flavor <dev flavor> --target lib/main_<flavor>.dart` if the app has flavors. On macOS, also run `fvm flutter build ios --debug --no-codesign` (with the same flavor flags). On other platforms the pbxproj/plist diff plus CI is the iOS check; say so in the report instead of skipping it silently. These are build-only commands. Never run the app.
6. Delete the reference app.

## Step 7: Upgrade GitHub Actions (if `.github/workflows/` exists)

1. Collect every `uses: owner/repo@ref` across `.github/workflows/*.y*ml`, skipping local `./...` paths.
2. Get each action's latest release with `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`. If there are no releases, use `gh api repos/<owner>/<repo>/tags --jq '.[].name'`.
3. Update each reference to the latest version, keeping the file's pin style: `@v6` → `@v7`, or a full SHA → the new tag's SHA with the version in a trailing comment.
4. For each major bump, read the release notes between the old and new majors and apply the required workflow changes (renamed or removed inputs, changed defaults, new permissions, raised runner/Node minimums). Don't guess.
5. Fix runner deprecation warnings from recent runs (e.g. Node 20 → 24) when a newer action major resolves them.

Action bumps can't be run locally. CI on the resulting PR is the check, so say that in the report. Note any open Dependabot PRs that this supersedes.

## Step 8: Fix analyzer errors

From the repo root (this covers every workspace package), run `fvm flutter analyze`. Fix every **error** and re-run until there are none. Leave warnings and info alone unless this upgrade introduced them.

## Step 9: Report

Write the summary to `UPGRADE_NOTES.md` at the repo root and also post it in chat:
- The Flutter SDK change (old → new).
- The upgraded-packages table from Step 4.
- Packages held back, and why.
- One bullet per code migration, naming the package and the reason.
- Native changes: each Android/iOS tooling version bumped (old → new) and which builds verified them, or a note that iOS couldn't be built on this platform.
- GitHub Actions bumped (old → new) per workflow, any release-note-driven edits, and the Dependabot PRs this supersedes.
- The final analyzer result.

If something couldn't be migrated safely, leave it pinned at the working version and explain why in `UPGRADE_NOTES.md`. Don't force it.

## Step 10: Hand off

- **Local run:** don't stage, commit, or push. List the changed files and suggest a short commit message (e.g. `upgrade flutter sdk and dependencies`).
- **CI run** (`GITHUB_ACTIONS` is set and the workflow exists to open this PR):
  1. If no git identity is set, use `github-actions[bot]` / `41898282+github-actions[bot]@users.noreply.github.com`.
  2. If the working tree is clean, stop and report that everything is current. Don't open an empty PR.
  3. On branch `chore/dependency-upgrade`, commit everything as `upgrade flutter sdk and dependencies` (no AI or tool attribution), then `git push --force-with-lease` to replace a leftover branch from an earlier run.
  4. If there's no open PR for the branch, run `gh pr create --title "upgrade flutter sdk and dependencies" --body-file UPGRADE_NOTES.md --label dependencies`. Otherwise refresh its body with `gh pr edit --body-file UPGRADE_NOTES.md`.
