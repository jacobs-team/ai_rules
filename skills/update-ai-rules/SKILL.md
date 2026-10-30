---
name: update-ai-rules
description: Add or change a rule or skill in the hosted ai_rules repo, commit and push it, confirm the installer refreshed this machine's copies, and load the change into the current session. Manual only - run only when the user types /update-ai-rules or names this skill.
disable-model-invocation: true
metadata:
  short-description: Change the ai_rules repo and reload it
  author: Jacob Blankenship
---

# Update ai_rules

Change the shared rules or skills, publish them, and make them live on this machine right away.

The repo is `https://github.com/jacobs-team/ai_rules`. Agents never read the clone: `tool/install.dart` copies it into `~/.ai_rules` and each agent's global files (`~/.claude/CLAUDE.md`, `~/.claude/skills/`, `~/.codex/AGENTS.md`, …). The clone's `.githooks/` re-run the installer after every commit, pull and rebase, so a commit refreshes this machine and a `git pull` refreshes every other one.

Invoking this skill is the user's request to commit and push the change (the `AGENTS.md` git exception for ai_rules).

## 1. Find the clone

The installed copy doesn't record where the clone lives. Check, in order:

1. `~/Desktop/projects/ai_rules` (the README's location).
2. A folder named `ai_rules` one level under the user's usual projects folder, whose `git remote get-url origin` is the repo above.

If neither exists, ask where it is. Never edit `~/.ai_rules` or any installed copy; they're overwritten on every install.

## 2. Sync first

```sh
git -C <clone> status --short
git -C <clone> pull --rebase
```

The pull runs the installer through the hook, so this machine also gets any rule pushed from another machine. If the clone has uncommitted changes you didn't make, leave them alone: never stash, reset or commit them, and stage only your own paths later. If the pull can't rebase because of them, tell the user and stop.

## 3. Make the change

Put it where the README says it belongs:

| Change | File |
|---|---|
| General rule (any language or tool) | `AGENTS.md`, in the section it fits |
| Dart/Flutter rule | `languages/flutter-dart.md` |
| New language | `languages/<lang>.md` plus its entry in `languages/README.md` and `tool/install.dart` (`languageDocs`) |
| New or changed skill | `skills/<name>/`, following `skills/README.md` |

Write rules the way the file already reads: short imperative bullets in the user's voice ("Never …", "Prefer …"), no history, no rationale paragraphs. Rewrite an existing rule in place when the new one changes it; never add a second rule that amends the first. Keep one rule (or one skill) per run so it gets one commit.

For a skill, all of these, or the installer refuses it:
- `SKILL.md` with the frontmatter in `skills/README.md`: `name` equal to the folder, a description ending "Manual only - run only when the user types /<name> or names this skill.", `disable-model-invocation: true`, and never `user-invocable: false`.
- `agents/openai.yaml` copied from an existing skill.
- A row in the `skills/README.md` table, and the approved count and names in the `skills/CANDIDATES.md` status line.

Then check the other docs the change affects: `PASTE.md` is a condensed `AGENTS.md` under 1,500 characters, so update it when the rule belongs in that short block; update `README.md` when the repo's layout or what agents get changes.

## 4. Commit and push

Stage only the paths you changed, then commit with a short, lowercase, imperative message naming the rule, with no body and no mention of the AI tool:

```sh
git -C <clone> add <paths>
git -C <clone> commit -m "add rule to <what it does>"
git -C <clone> push
```

Read the commit output: the hook prints the installer's report. Any `warn` line (a refused skill, a conflicting file) is a problem to fix before you're done. If the push is rejected because the remote moved, `git pull --rebase` and push again. If it fails for auth or network, say so; the local install still happened.

## 5. Confirm this machine has it

Check what the agents actually read, not the clone:

- `~/.ai_rules/<changed path>` matches the clone's file (`diff` or compare hashes).
- For a rule: the new text is in `~/.claude/CLAUDE.md` (or `~/.claude/rules/<lang>.md`'s target in `~/.ai_rules/languages/`).
- For a skill: `~/.claude/skills/<name>/SKILL.md` and `~/.agents/skills/<name>/SKILL.md` exist.

If they don't match, the hook didn't run. Check `git -C <clone> config core.hooksPath` is `.githooks`, then run the installer by hand from the clone: `dart tool/install.dart`, or `fvm dart tool/install.dart` when `dart` isn't on the `PATH`. That also restores the hooks path.

## 6. Reload it here

- **Skills:** Claude Code picks up new and changed skills in `~/.claude/skills/` without a restart. Other tools load skills at session start.
- **Rules:** every agent reads its rules file once, at session start. To follow a changed rule in this session, read the installed file now (`~/.claude/CLAUDE.md`, or the changed `~/.ai_rules/languages/<lang>.md`) and apply the new text from here on. Other open sessions pick it up when they restart.
- **Other machines:** they get it on their next `git pull` in their clone, which runs the installer. Chat apps need `PASTE.md` pasted again.

## 7. Report

One short block: what changed and where, the commit hash and that it's pushed, what you verified in step 5, and anything from the installer's warnings or the push that needs the user.
