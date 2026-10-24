---
name: rename-project
description: Rename a project freshly cloned from the flutter_template repo - Dart package name, iOS/Android bundle IDs and display names, the coverage badge gist, and every remaining template reference. Manual only - run only when the user types /rename-project or names this skill.
disable-model-invocation: true
metadata:
  short-description: Rename a flutter_template clone
  author: Jacob Blankenship
---

# Rename Project From Template

Fully rename a fresh clone of `flutter_template` into its own project: Dart package, platform bundle identifiers, display names, and every leftover reference. Use `fvm flutter` / `fvm dart` for all project CLI commands. Never run the app; ask the developer to run it.

**Editing mode:** this skill does a lot of find/replace. In manual/ask mode, make each file change through the normal reviewable edit flow (no `sed` or scripted replace). In auto/bypass mode, scripted replace is fine. See `AGENTS.md`.

## Step 0: Gather inputs

Three values are required. Derive defaults, then confirm them with the user before changing anything:

- **`project_name`** (snake_case Dart package name, e.g. `my_app`). Default to the repo folder name if it is valid snake_case.
- **`display_name`** (human-readable app name, e.g. `My App`). Default to the title-cased `project_name`.
- **`bundle_id`** (reverse-DNS, e.g. `com.example.myapp`). There's no safe default, so ask the user. Make sure it is valid on both platforms: Android allows underscores but not hyphens, and iOS allows hyphens but not underscores. So use all-lowercase alphanumeric segments with no separators, start each segment with a letter, and keep the same ID on both platforms.

Also record the old values for the find/replace sweep: the package `flutter_template`, plus the current display names and bundle IDs in `android/app/build.gradle*` and `ios/Flutter/*.xcconfig`.

## Step 1: Dart package rename

1. In `pubspec.yaml`, set `name: <project_name>` and update the `description`.
2. Replace every `package:flutter_template/` import with `package:<project_name>/` in all `.dart` files under `lib/` and `test/`. That includes generated files: they get regenerated anyway, but this keeps the tree consistent if codegen fails midway.
3. Resolve and regenerate:

   ```
   fvm flutter pub get
   fvm dart run build_runner build --delete-conflicting-outputs
   fvm flutter gen-l10n
   ```

## Step 2: Bundle IDs and app names (rename CLI)

1. If the rename CLI isn't installed, ask before installing it (`fvm dart pub global activate rename`).
2. Apply the new identifiers:

   ```
   fvm dart pub global run rename setBundleId --targets android,ios --value <bundle_id>
   fvm dart pub global run rename setAppName --targets android,ios,web --value "<display_name>"
   ```

3. The rename CLI only changes base values. The template uses flavors, so check and fix the flavor layer by hand:
   - `android/app/build.gradle*`: the `namespace`, each flavor's `applicationId`/`applicationIdSuffix`, and the `appName` manifest placeholder for each flavor (development, staging, production). Keep the existing suffix scheme (e.g. `.dev`, `.stg`) on the new bundle ID.
   - The Kotlin `MainActivity` package: if its directory under `android/app/src/main/kotlin/` reflects the old package, move it to match the new `namespace` and update its `package` declaration.
   - `ios/Flutter/*.xcconfig` and `ios/Runner.xcodeproj/project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER` for each configuration and `FLAVOR_APP_NAME` for each flavor (e.g. `<display_name> Dev` for development).

## Step 3: Sweep the remaining references

1. Search the whole repo for leftovers, excluding `.git`, `build`, `.dart_tool`, and `.fvm` (use `rg -i` or the editor's search, which work on Windows and macOS):

   ```
   rg -i "flutter_template"
   rg -i "<old display name>"
   ```

2. Fix every hit. Expect them in:
   - `.github/workflows/*.yaml`: the workflow `name`.
   - `README.md`: the title and description. The coverage badge is repointed in step 3. Remove or repoint any other badge that still points at the template's resources.
   - `web/index.html`: `<title>` and the meta description. `web/manifest.json`: `name`/`short_name` (if the rename CLI didn't already).
   - `.idea/` module files, if present.
   - Code comments or docs that mention the template name.
3. Set up the project's own coverage badge gist. This creates a public gist and stores a secret on the GitHub repo, so **confirm with the user before running any of it**:
   1. Check auth with `gh auth status`. The token needs the `gist` scope (`gh auth refresh -s gist` if missing). Note the account login (`<gist_owner>`) and the repo slug from `gh repo view --json nameWithOwner`.
   2. In a temp folder, write `coverage.json` containing `{"schemaVersion":1,"label":"Coverage","message":"unknown","color":"lightgrey"}`, then create the gist and record its ID from the returned URL:

      ```
      gh gist create <temp-folder>/coverage.json --public --desc "<project_name> coverage badge"
      ```

   3. Set the secret the workflow uses: `gh auth token | gh secret set GIST_TOKEN --repo <owner/repo>`. Tell the user this stores their gh OAuth token as the secret, and that they can swap in a dedicated PAT with only the `gist` scope.
   4. In `.github/workflows/main.yaml`, uncomment the `Extract Coverage` and `Update Coverage Badge Gist` steps, set `gistID:` to the new ID, and guard both with `if: github.ref == 'refs/heads/main'` so PR runs don't overwrite the badge.
   5. In `README.md`, point the `[coverage_badge]` link at `https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/<gist_owner>/<gist_id>/raw/coverage.json`.
   6. The badge reads "unknown" until the first successful CI run on `main` updates the gist.
4. Repeat the search until it finds nothing outside `.git`.

## Step 4: Validate dynamic values in the diff

The rename CLI replaces some build-time placeholders with the literal app name. Review the full diff (`git diff`) and restore every dynamic value:

- `android/app/src/main/AndroidManifest.xml`: `android:label` must stay `${appName}` (the flavor value comes from the Gradle manifest placeholder), never the literal display name.
- `ios/Runner/Info.plist`: `CFBundleDisplayName`/`CFBundleName` must keep their `$(...)` build-setting references (e.g. `$(FLAVOR_APP_NAME)`).
- Any other `${...}` (Gradle) or `$(...)` (Xcode) reference that the CLI replaced with a literal must go back to the placeholder.

Rule of thumb: a removed line containing `${...}` or `$(...)` that was replaced by a hardcoded string is a regression, so restore the placeholder. Literal old-name strings (e.g. in the README or `web/manifest.json`) are the only things that should become the new name.

## Step 5: Verify

```
fvm flutter pub get
fvm flutter analyze
```

Fix errors only. Ask the developer to run the app from their IDE to confirm it boots and shows the new display name.

## Step 6: Report

Summarize the old → new values for the package, bundle IDs (per flavor), and display names (per flavor), the files touched in the sweep, the gist ID and `GIST_TOKEN` setup, and the analyzer result. Remind the user the badge updates after the first CI run on `main`. Don't stage or commit unless asked.
