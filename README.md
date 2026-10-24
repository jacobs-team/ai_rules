# ai_rules

One repo of rules and skills for every AI coding agent, on every machine, in every project. Edit here, commit, and every agent picks it up.

## Where to add rules

There are only two places to edit:

- **General rule** (any language or tool): `AGENTS.md`.
- **Flutter/Dart rule**: `languages/flutter-dart.md`. New languages: see `languages/README.md`.

Everything the agents read is generated from those by `tool/install.dart`. Never edit the installed copies; they carry an `ai_rules:generated` notice and are overwritten on every run.

| Path | What it is |
|---|---|
| `AGENTS.md` | **The master.** Every agent loads it in every project |
| `languages/flutter-dart.md` | Loaded only for Dart/Flutter work (path globs, or the rule in `AGENTS.md`) |
| `skills/<name>/` | The approved skills, manual only. See `skills/README.md` |
| `skills/CANDIDATES.md` | Approval log. Nothing is added without your approval |
| `PASTE.md` | Short paste block for chat apps that can't read files |
| `settings/*.json` | Keys merged into tools' own settings (commit attribution off, the `superpowers` plugin off) |
| `tool/install.dart` | Installs everything into each agent's global locations |
| `.githooks/` | Re-run the installer after every commit, pull and rebase |
| `.github/workflows/agent-format-check.yml` | Twice-monthly check of each vendor's docs for format changes |

## Set up a machine

Clone the repo anywhere you keep projects (e.g. `~/Desktop/projects/ai_rules`) and run the installer. It needs Dart on the `PATH`, or an FVM global version (`fvm global <version>`).

```sh
git clone https://github.com/jacobs-team/ai_rules.git ~/Desktop/projects/ai_rules
cd ~/Desktop/projects/ai_rules
dart tool/install.dart
```

The first run also points git at `.githooks/`, so from then on the installer re-runs by itself. Re-run it by hand after installing a new agent.

Agents never read the clone. The installer keeps its own copy of `AGENTS.md`, `languages/` and `skills/` at `~/.ai_rules` (`%USERPROFILE%\.ai_rules` on Windows), and everything points there. So the clone can live anywhere or move, and half-finished edits in it never reach an agent.

### Mac (company-managed)

The Mac's global git config rewrites every GitHub URL to SSH, and the active `gh` account is the work account. Before cloning, scope the personal login to the `jacobs-team` org only:

```bash
git config --global url."https://jcblol@github.com/jacobs-team/".insteadOf "git@github.com:jacobs-team/"
git config --global --add url."https://jcblol@github.com/jacobs-team/".insteadOf "https://github.com/jacobs-team/"
```

The existing `gh auth git-credential` helper then supplies the jcblol token for `jacobs-team` repos only. Check it with `git ls-remote https://github.com/jacobs-team/ai_rules.git`.

### Switching from `ai-instructions`

Remove the old setup first, or tools will load both: `& $HOME\.ai-instructions\install.ps1 uninstall` on Windows, `~/.ai-instructions/install.sh uninstall` on the Mac. Then run this installer. If it warns about `~/.grok/AGENTS.md`, delete that file.

## Daily use

1. Edit `AGENTS.md`, `languages/`, or `skills/`.
2. Commit. The hook reinstalls on this machine.
3. Push. On the other machine, `git pull` and the hook reinstalls there.

To try an edit before committing, run `dart tool/install.dart` by hand.

## What each agent gets

| Agent | Master | Flutter/Dart doc | Skills (manual only) |
|---|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | `~/.claude/rules/flutter-dart.md`: a `paths:` rule that imports the doc only when a Dart file is touched | `~/.claude/skills/`, `/<name>` |
| Codex CLI / IDE | `~/.codex/AGENTS.md` | Rule in `AGENTS.md` | `~/.agents/skills/`, `$<name>` |
| Copilot CLI + VS Code | `~/.copilot/copilot-instructions.md` (VS Code's local agent also reads `~/.claude/CLAUDE.md`) | `~/.copilot/instructions/flutter-dart.instructions.md` (`applyTo`) | `~/.agents/skills/`, `/<name>` |
| Gemini CLI | `~/.gemini/GEMINI.md` | Rule in `AGENTS.md` | `~/.agents/skills/`, plus a `/<name>` command per skill in `~/.gemini/commands/` |
| Antigravity | `~/.gemini/GEMINI.md` | `~/.gemini/config/rules/flutter-dart.md` (`trigger: glob`) | `~/.gemini/config/skills/` (app, IDE), `~/.gemini/antigravity-cli/skills/` (CLI), `/<name>` |
| Cursor (IDE + CLI) | `~/.cursor/rules/ai_rules.mdc` (`alwaysApply: true`) | `~/.cursor/rules/flutter-dart.mdc` (`globs`) | Reads `~/.agents/skills/` and `~/.claude/skills/`, `/<name>` |
| Grok Build | Reads `~/.claude/CLAUDE.md` | Reads the short pointer in `~/.claude/rules/` (Grok ignores `paths:`, so it only sees the pointer) | Reads `~/.claude/skills/` and `~/.agents/skills/`, `/<name>` |
| Claude Desktop, ChatGPT, grok.com | Paste `PASTE.md` | n/a | Attach a `SKILL.md` |

Settings it merges (every other key is kept, and the original is backed up once as `*.ai_rules.bak`):

- `~/.claude/settings.json`: `attribution` set to empty, so no co-author or "Generated with" lines. It also turns off the `superpowers` plugin, whose start-up hook loads a full skill and tells the model to use skills on its own.
- `~/.copilot/settings.json`: `includeCoAuthoredBy: false`.

### Keeping skills out of context

Every `SKILL.md` has `disable-model-invocation: true` (Claude, Copilot, Cursor, Grok), and every skill has `agents/openai.yaml` with `allow_implicit_invocation: false` (Codex). The tools only list the name and description; the body loads only when you invoke the skill. Gemini and Antigravity have no manual-only flag, so every description also says "Manual only", and `AGENTS.md` tells every agent never to pick a skill on its own. The installer refuses a skill that doesn't meet this and removes any copy it installed before.

## Verify each agent

Run these once after setting up a machine, and again after big agent updates.

**Skills stay out of context (every agent).** In a fresh session, ask: *"Without opening any files or running any skill, list the steps of the stacked-mrs skill."* It should only know the one-line description. Then invoke it (`/stacked-mrs`, or `$stacked-mrs` in Codex) and it should load.

| Agent | Check |
|---|---|
| Claude Code | `/memory` lists `~/.claude/CLAUDE.md`. In a Dart project, `/context` shows the Flutter doc only after a `.dart` file has been read. `/skills` lists the six skills. `/plugin` shows `superpowers` disabled. |
| Codex | `/skills` lists the six. No command lists loaded instructions, so ask *"Summarize your global instructions"*. |
| Copilot CLI | `/instructions` lists `copilot-instructions.md`. `/skills list`. |
| VS Code Copilot | The References list under a reply shows the instruction files. The `/` menu lists the skills. |
| Gemini CLI | `/memory show` contains the master. `/stacked-mrs` exists as a command. |
| Antigravity | The Customizations panel lists `GEMINI.md`, the Flutter glob rule, and the skills. |
| Cursor | Settings → Rules lists `ai_rules` and `flutter-dart`. If the master shows up twice (once from `~/.claude/CLAUDE.md`), tell me. |
| Grok Build | `grok inspect` lists `~/.claude/CLAUDE.md` (~2.3K tokens) and `~/.claude/rules/flutter-dart.md` (a few dozen), and no `~/.grok/AGENTS.md`. |

## Updating for tool changes

`.github/workflows/agent-format-check.yml` runs on the 1st and 15th of each month. It reads the official docs listed in `.github/agent-sources.yml` and opens a PR with a per-vendor summary when a tool changes its file names, locations or frontmatter. It never pushes to `main`, never adds skills, and never rewrites your rules. It needs one secret, which you set yourself:

```bash
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo jacobs-team/ai_rules
```

Without the secret, the run only writes a job-summary note. In the `jacobs-team` org, also turn on **Allow GitHub Actions to create and approve pull requests** in both the org's and the repo's Actions settings.

## Known gaps

- **Codex commit attribution** is an account setting, and Codex's own instructions override `AGENTS.md` on this. Turn it off in your ChatGPT/Codex settings.
- **Copilot CLI** has an open bug (github/copilot-cli#4438) where a manual-only skill can't be invoked at all. It stays out of context either way; ask the agent to use the skill by name instead (`AGENTS.md` tells it where to read it).
- **Duplicate skill names:** Copilot, Cursor and Grok read both `~/.claude/skills/` and `~/.agents/skills/`, so their `/` menus may list a skill twice.
- **Chat apps** can't read files: paste `PASTE.md` again after major changes to `AGENTS.md`.

## Uninstall

```sh
dart tool/install.dart --uninstall
```

Removes every file and folder it installed (including `~/.ai_rules`), restores the files it backed up, and turns the repo's hooks off. Merged settings are left as they are.
