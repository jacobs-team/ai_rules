---
name: stacked-mrs
description: Split a completed branch into a stack of small, reviewable MRs/PRs. Each one is its own branch, branched off the previous, containing the smallest cohesive slice of the work (e.g. renames, models, repository, bloc, UI). Manual only - run only when the user types /stacked-mrs or names this skill.
disable-model-invocation: true
metadata:
  short-description: Split a finished branch into stacked MRs
  author: Jacob Blankenship
---

# Stacked MRs

Split one large completed branch into a stack of small, reviewable MRs (PRs on GitHub). Each MR is a branch built on top of the previous one, so each diff can be read on its own.

The goal is reviewer ergonomics: a teammate can read each MR in a short time and understand it with only the context it provides.

Invoking this skill is the user's request to create the stack's branches and stage each slice. Never commit or push. The user commits each slice.

---

## Inputs

Before doing anything else, ask the user two questions (use the tool's question UI if it has one):

1. **Source branch:** the completed branch to split. The default is the current branch (`git rev-parse --abbrev-ref HEAD`).
2. **Base branch:** what the stack sits on. The default is `main`.

Don't assume. Wait for the answers before gathering diffs or planning, and use them everywhere `<source-branch>` and `<base-branch>` appear below.

**Branch naming:** use conventional-commit prefixes (`feat/`, `fix/`, `chore/`, `refactor/`, `test/`, `docs/`). Pick the prefix that matches the slice's intent plus a short kebab-case suffix (e.g. `refactor/menu-item-rename`, `feat/update-display-price`). Propose names in the plan; the user can change any of them before execution.

Once the inputs are confirmed, gather:

```bash
git status
git log --oneline <base-branch>..<source-branch>
git diff --stat <base-branch>...<source-branch>
git diff <base-branch>...<source-branch> --name-only
```

Read the file diffs against the base branch to understand what actually changed. Don't plan from filenames alone.

---

## Planning the stack

Group the changes into the smallest cohesive slices a reviewer can hold in their head. The typical order, from the bottom of the stack to the top:

1. **Pure renames / moves** (no behavior change)
2. **Models** (new fields, classes, factories, and getters with no callers yet)
3. **Repository / data layer** (new methods, parsing changes)
4. **Bloc / cubit / state** (new events, state fields, handlers)
5. **Shared widgets / helpers** (extensions, reusable widgets)
6. **UI wiring** (views consuming the new state and widgets)
7. **Cleanup / removal** of old code paths

Rules:

- Each MR must compile and analyze cleanly on its own. If a slice would break the build, fold it forward or backward.
- Small bridging changes are OK to keep a slice separate: temporary call-site updates, stub implementations, or `@Deprecated` shims that let the lower slice compile without the upper one. If you add a bridge in a lower slice, undo it in the upper slice that replaces it. Call out each add/remove pair in the plan.
- Existing tests move with the code they cover, in the same MR. Moving and adapting tests is fine, but never create new ones (see `AGENTS.md`).
- If a file changed for more than one reason, split its diff across MRs with partial checkout (`git checkout -p`), not whole-file moves.
- Aim for under 750 lines of diff per MR. Bigger is fine if the slice is genuinely atomic.
- If a slice would be under about 50 lines on its own, merge it with the most closely related neighbor. Keep a tiny slice standalone only if merging would mix unrelated concerns.
- Any slice over about **1000 lines of diff** must be explicitly accepted by the user during planning. Name it, give its rough size, explain why it can't be split further, and wait.

Present the plan as a numbered list, each item with its branch name, what it contains, and the files it touches. Iterate until the user agrees.

**Don't start executing until the user confirms the plan.**

---

## Executing the stack

For each slice, in order:

1. Branch from the previous slice (or from `<base-branch>` for slice 1):
   ```bash
   git checkout <previous-branch-or-base>
   git checkout -b <new-branch>
   ```
2. Pull in only that slice's changes from the source branch:
   - Whole files: `git checkout <source-branch> -- <path>`
   - Partial files: `git checkout -p <source-branch> -- <path>`
3. Refresh dependencies before analyzing. Run the project's install command at the repo root (`fvm flutter pub get` for Flutter), and again inside any sub-package whose dependencies changed in this slice. Stale dependency state shows up as false "undefined name" errors.
4. If the source branch added dependencies that this slice doesn't use yet, leave them out. The later slice that introduces the code using them also introduces the dependency.
5. Run the analyzer and fix **errors only**: `fvm dart analyze .` for Flutter, or the project's linter for other stacks.
6. Stage by explicit path. **Don't commit.**
   ```bash
   git add <paths>
   git status
   ```
7. Report the branch name, the staged files, and the analyzer result. Ask the user to check and commit, and to confirm before you move on.

After the user commits, move on to the next slice.

---

## Constraints

- Stage only. The user commits and pushes, and no commit message mentions any AI tool.
- Never use `git add -A` or `git add .`. Stage by explicit path.
- Never skip hooks or force anything.
- Don't fix lint info or warnings, only errors.
- If a slice can't be cleanly extracted (e.g. a file's changes are tangled across two slices), tell the user before forcing a split.

---

## Recovery

If a slice breaks the build:

- Don't do a destructive reset. Find the missing piece.
- Check with the user before adding temporary changes to fix a slice.
- Either fold the missing piece into this slice or move this slice later in the stack.
- Show the user the revised plan before continuing.
