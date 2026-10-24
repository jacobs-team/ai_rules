# Language docs

`AGENTS.md` loads none of these by default. Each file applies only when the task involves that language.

| File | Applies when |
|---|---|
| `flutter-dart.md` | `*.dart`, `pubspec.yaml`, `analysis_options.yaml`, or fvm/flutter/dart/melos commands |

## Adding a language (e.g. `python.md`)
1. Create `languages/<lang>.md` with no frontmatter; the installer adds each tool's glob frontmatter.
2. Start the body with a one-line **Scope** sentence ("apply only when … otherwise ignore").
3. Add one line to the "Language docs" section of `AGENTS.md` naming the trigger files. This is the fallback for tools with no glob support (Codex, Gemini CLI, Grok, the chat apps).
4. Add an entry to `languageDocs` in `tool/install.dart` with the file name, a description, and its globs. The installer writes the per-tool rules from it (Claude `~/.claude/rules/`, Copilot `~/.copilot/instructions/`, Antigravity `~/.gemini/config/rules/`, Cursor `~/.cursor/rules/`).
5. Add a row to the table above.
6. End the file with a `## Current language` section: the version it was reviewed at, links to the official release notes, and one short line per recent release with the features agents wouldn't reach for by default. `.github/workflows/language-check.yml` reads those links monthly and opens a PR when a newer release adds something; it may edit nothing outside that section.
