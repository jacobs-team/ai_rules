---
name: design-mockups
description: Mock up, explore, or compare UI designs for a Flutter widget or screen before building it. Produces phone-framed HTML mockups that match the app's real design tokens and screenshots them inline. Manual only - run only when the user types /design-mockups or names this skill.
disable-model-invocation: true
metadata:
  short-description: Phone-framed HTML UI mockups from real tokens
  author: Jacob Blankenship
---

# Design Mockups

Mock UI ideas as a single self-contained HTML file in a phone frame, styled with the app's real design tokens, then screenshot it so the options show up inline in chat. HTML is the medium because the developer runs the Flutter app from their IDE. You can render and screenshot HTML, but you don't run the app.

## Workflow

1. **Read the real tokens.** Pull values from the app's design system so the mockups look like the app, not a generic guess. In a melos or pub workspace, use the app package that owns the screen (e.g. `<app>/lib/...`).
   - Look in `lib/design_system/` first. It is typically `app_palette.dart` (colors; use the light scheme), `app_design.dart` (spacing and radius scales), and `app_theme.dart` (colors if there is no palette file, Google Fonts for headings and body, and component shapes for cards, sheets, chips, and buttons). If there's no `design_system/`, find the theme via `ThemeData`/`ColorScheme`.
   - Read the widget being redesigned and its neighbors, so you reuse the app's existing visual language.
   - If the repo keeps a design log (e.g. `docs/design/DESIGN_LOG.md`) that names a current mockup pick under `design/mockups/`, always include that pick as one of the options.

2. **Build one HTML file** at `design/mockups/<feature>_designs.html`. Mirror the tokens into CSS variables copied from the palette (`:root { --primary: ...; --surface: ...; }`) and load the matching Google Fonts via `<link>`. Put each design in a phone-sized frame, with a dimmed scrim behind a bottom sheet or screen so it reads like the real app.

3. **Show N distinct directions side by side, plus the current version for reference.** Make them genuinely different approaches (A/B/C), not three tweaks of one. Label each column with a short name and a one-line description of the idea and its trade-off.

4. **Screenshot it** with whatever browser tool is available (e.g. chrome-devtools MCP: `new_page` → `file:///<abs-path>`, `resize_page` → ~1480×900, `take_screenshot` with `fullPage: true`), so the images land in chat. If no browser tool is available, say so and give the file path.

5. **Present and recommend.** Describe each direction, give a recommendation with reasoning, then ask which one to build (offer a "mix / iterate" option). Build only after the user picks.

## Defaults and options
- The default output dir is `design/mockups/`.
- Reuse existing components where they fit rather than inventing look-alikes. Map a design back to real widgets when asked.
- Offer light and dark versions only if the user asks for both.
- The mockup is a rough reference. What ships is the Flutter implementation, which may diverge (for example, a real shared widget replaces a mocked element). Say so rather than implying the HTML is the source of truth.

## Common mistakes
- Inventing colors, radii, or fonts instead of reading them from the design system. The point is fidelity to the app.
- Producing three near-identical variants instead of distinct directions.
- Returning a file path with no screenshot when a browser tool is available.
- Trying to run the Flutter app to render the UI.
