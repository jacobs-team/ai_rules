# Skills (canonical home)

Every approved skill lives here as `skills/<name>/`. Nothing gets added without your explicit approval (`CANDIDATES.md` tracks the decisions). Skills are **manual-only**: no agent may load, read, or invoke one unless you type its command or name it (see `AGENTS.md`).

## Approved skills
| Skill | What it does | Files |
|---|---|---|
| `autopilot` | Settles a goal with you, then works unattended until it is verified done, with a progress doc and a 10-minute restart job | `SKILL.md`, `agents/openai.yaml` |
| `code-clarity-refactor` | Marks unclear code with `TODO(clarity)`, you prune them, then it applies code-level clarity fixes one at a time | `SKILL.md`, `agents/openai.yaml` |
| `design-mockups` | Phone-framed HTML mockups of 2–3 distinct UI directions using the app's real tokens, screenshotted inline | `SKILL.md`, `agents/openai.yaml` |
| `find-skills` | Searches skills.sh / `npx skills` for installable skills. *Third-party (vercel-labs, MIT)* | `SKILL.md`, `LICENSE`, `NOTICE.md`, `agents/openai.yaml` |
| `rename-project` | Renames a fresh `flutter_template` clone: package, bundle IDs, display names, leftovers | `SKILL.md`, `agents/openai.yaml` |
| `stacked-mrs` | Splits a finished branch into stacked, small MR/PR branches. Stages each slice; you commit | `SKILL.md`, `agents/openai.yaml` |
| `upgrade-dependencies` | Flutter SDK + all deps (single package or melos/pub workspace), migrations, native Android/iOS, GitHub Actions | `SKILL.md`, `agents/openai.yaml` |
| `update-ai-rules` | Changes a rule or skill in this repo, commits and pushes it, checks the installed copies, and loads it into the current session | `SKILL.md`, `agents/openai.yaml` |

## How to invoke (per tool)
| Tool | Invoke | What keeps it hidden otherwise |
|---|---|---|
| Claude Code | `/<name>` | `disable-model-invocation: true` |
| Codex CLI/IDE | `$<name>` (or the `/skills` picker) | `agents/openai.yaml` -> `allow_implicit_invocation: false` |
| Gemini CLI | `/<name>` (a command the installer writes to `~/.gemini/commands/`) | No manual-only flag. Gemini asks for consent before activating any skill |
| Antigravity | `/<name>` | No manual-only flag. The description says "Manual only" |
| Copilot CLI / VS Code | `/<name>` | `disable-model-invocation: true` |
| Cursor | `/<name>` | `disable-model-invocation: true` |
| Grok Build | `/<name>` | `disable-model-invocation: true` |
| Chat apps (Claude Desktop, ChatGPT, grok.com) | Paste or attach the SKILL.md | n/a |

Every tool also follows the `AGENTS.md` skills rule, which covers tools without a native flag.

## Layout of a skill
```
skills/<name>/
  SKILL.md              # name == folder; lowercase-hyphen
  agents/openai.yaml    # Codex: policy.allow_implicit_invocation: false
  LICENSE / NOTICE.md   # third-party only
  references/ scripts/  # optional helpers
```
Required frontmatter:
```yaml
---
name: <name>
description: <one line>. Manual only - run only when the user types /<name> or names this skill.
disable-model-invocation: true
metadata:
  short-description: <few words>
  author: <author>
---
```
Never set `user-invocable: false`. Combined with the flag above, it makes the skill unreachable.

The installer refuses any skill that breaks these rules and removes copies it installed earlier.

## Adding another skill (after approval)
1. Copy it into `skills/<name>/`, using a lowercase-hyphen name.
2. Clean it against `AGENTS.md`: remove test/coverage steps, commit/push steps you didn't ask for, AI attribution, approval gates, Bloc-only or dart_mappable mandates, secrets, and personal data.
3. Add the frontmatter above and `agents/openai.yaml` (copy an existing one).
4. List the skill above, mark it ✅ in `CANDIDATES.md`, then commit. The hook installs it on this machine; other machines get it on their next `git pull`.
