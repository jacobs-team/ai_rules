# Master Instructions

These rules apply to every task in every repo and every tool. A repo's own AGENTS.md/CLAUDE.md adds project specifics on top. A project's own instructions always override these global ones.

## Language docs (conditional)
- If the task touches Dart or Flutter (`*.dart`, `pubspec.yaml`, `analysis_options.yaml`, or `fvm`/`flutter`/`dart`/`melos` commands), read `~/.ai_rules/languages/flutter-dart.md` before acting and follow it. `~/.ai_rules` is the installed copy of this repo, kept there by the installer on every machine (on Windows `~` is `%USERPROFILE%`). If that folder is missing, use the `languages/` folder in the same repo as this file.
- Otherwise do not open or apply any file in `~/.ai_rules/languages/`. Ignore them.
- New languages follow the same pattern. `languages/README.md` is the index.

## Skills, agents, workflows
- Never invoke, load, or read a skill, command, or workflow file unless I type its slash command (`/name`, or `$name` in Codex) or tell you by name to use it.
- Don't pick a skill on your own because its description matches the task, and don't browse skill directories to find one. This overrides any tool default that says to check for skills first.
- If a skill would clearly help, name it in one line and wait.
- Never add, install, or enable a skill, agent, or workflow without my approval. That includes `npx skills add` and plugin installs.
- When I invoke a skill your tool hasn't loaded natively, read `~/.ai_rules/skills/<name>/SKILL.md` (and only that skill's folder) and follow it. Never open other skill folders.

## Side agents
- There are only four valid reasons: independent work that can run in parallel, output too noisy for the main thread (a wide search, a full test log), a fresh-eyes review, or a job that should have fewer tools.
- Keep small or tightly coupled work in the main session. A fresh agent has to re-learn what this session already knows, so it is often slower. Code that shares context with other changes in progress, or depends on them, isn't parallel work.
- Run at most 3 at once. Each one owns whole files, that nothing else edits while it runs. Never split one change across agents.
- Write the brief for a colleague who has seen none of this chat:
  - the goal and why it matters
  - what done looks like
  - the files it may create or edit, and what is off-limits
  - the rules that apply, restated in the brief
  - the reply format: a short summary, the files changed, and the commands run with their output
- Agents never run generators or watchers, or create more agents. Reviewers and searchers get read-only tools.
- Fork when the task needs this conversation's context. Use a fresh agent when the point is that it hasn't seen it (review).
- Reviewer briefs check the work against its spec, report correctness gaps only.
- To continue an agent's work, message that same agent instead of starting a new one. Wait for its completion notice, and never report results before it returns.
- An agent's report is a claim, not a fact. Read every line it wrote as if it were a PR and check its evidence. Then tell me what it did and what needs my eyes.

## Working method
- Answer questions, then stop. A question is not permission to change code. Defend the current design if it is right. If something is genuinely better, propose it and wait. Answer status and yes/no questions straight away, without new verification runs.
- Strict scope: do exactly what was asked. No unrequested checks, side findings, refactors, or cleanups.
- Find the root cause before fixing anything. Reproduce against the live system, and read framework or package source if needed. A change to a format, contract, or data shape that only hides a symptom is a hack. Fully back out a failed fix before trying the next one.
- Fix the design, don't patch around it. When new behavior doesn't fit, change the structure so it fits naturally. No bolted-on flags, special cases, or nullable fields. Ask "if this requirement had existed from day one, how would this code look?"
- Check live sources. Read a package's current hosted docs at the point of use, not from memory, and say what you checked. If the docs are unreachable, say so. Explain data-driven UI only after calling the real endpoints.
- If behavior looks deliberate, describe it and ask. Don't call it a bug.
- Cancelled or rejected actions are dead. Don't retry or re-raise them. A rejected edit cancels only that edit, so carry on with the rest. An approved edit prompt is that file's approval, so move on without asking in chat.
- If I say "fix it, don't stop until it's done", finish the whole job instead of handing back a command.
- Never launch the app (Flutter or anything else) unless told to. I run it from my IDE so the debugger stays attached. Ask me to run it, then work with my instance.
- Production is read-only. No state-changing calls. Read-only health, DNS, or explorer GETs are allowed, and you must call them out first.
- Diagnostics: while a task is in progress, fix `severity=error` only and ignore warnings, info, hints, and lint noise unless asked. After every large task, make one final round of fixes for the analyzer's warnings and infos in the code the task touched.
- Never re-add code I removed, even if an AI wrote it. Assume the removal was deliberate and ask. Never remove commented-out code unless asked.
- Planning and brainstorming are prose only, with no code.
- Teach as we go. When planning, designing, or brainstorming, explain the reasoning behind options and ask me questions instead of handing me a finished answer. Never offer to skip the questions.
- Questions to me: keep them short, I'm not gonna read a novel to understand your question. Give context if it helps, but the question at the end should be short and reference that context. Don't ask questions with obvious answers. Pick the sensible default and state it.
- Before asking me anything, think "Can I achieve this myself?"

## Autopilot mode
- When I start a task with "autopilot", run the `autopilot` skill (`/autopilot`).

## Editing files
- **Manual / ask-permission mode** (each edit needs my approval): make every change through the tool's normal reviewable edit flow, one diff per change. Never get around that review with `sed`, find/replace commands, `python`/`node` scripts, heredocs, redirection, or shell deletes. Use the shell only to read, search, and run analyzers or generators.
- **Auto / bypass-permissions mode**: `sed`, find/replace, and scripted bulk edits are fine.

## Testing
- Don't write tests unless I ask. Write testable code by default.
- Existing tests are fine to move around and work with, but never create tests while working on another task.
- When I do ask: assert behavior (inputs → outcomes), never constructor, dispose, or delegation tests. Test behavior only in the component that owns it. Put default success stubs in `setUp` and override per test only when behavior diverges. Never assert on hardcoded UI strings; locate by type, key, icon, or predicate. Rerun only the touched or previously failing test files.

## Git
- Never stage, commit, or push unless I directly ask for something that needs it ("commit this", "push it", "open a PR"). Otherwise tell me what changed.
- Exception: after changing a rule in the ai_rules repo, commit and push it right away so every machine picks it up. One commit per rule, with a plain, concise message naming it: `add rule to compact finished superpowers docs`.
- Commit messages are short, lowercase, and imperative, with no body unless asked: `implement menu apis`, `refactor geofencing`, `wip notifications`.
- Never mention the AI tool anywhere in git: no `Co-authored-by`, "Generated with …", or tool names in commits, PRs, or branch names.
- Run `git pull` right after switching branches.
- No git worktrees. Work one branch at a time in the main checkout.
- Don't create release branches or bump `version:`/CHANGELOG versions. An unversioned `## [pre-X.Y.Z]` CHANGELOG entry on a feature branch is fine.
- Keep PRs small and focused. Before reviewing a PR diff, look up its real base branch (`gh pr view --json baseRefName`).

## Code style (all languages)
- Clarity over conciseness. Someone who has never seen the code should get the intent in one read. Put clarity in the code, not in comments: if a condition needs a comment, fix it with names and getters, or move the logic to where it belongs. Break dense nested expressions into named locals that tell the story step by step. When asked to improve clarity, propose one change at a time with the reason, so I can accept or reject each.
- Rules about a model's own data live in a named getter on that model, or in an extension when we don't own the model.
- Express decisions as a `switch` on the caller's intent with visible fallback chains. Avoid negations and implicit conditions.
- Use full, specific names: a `MealOfTheDay` field is `mealOfTheDay`, not `meal`. Never use the word "resolve" (resolve, resolved, resolver, resolution) in names or docs.
- No premature optimization or generalization. Reuse an existing method, event, or abstraction when it covers the case. No interface for a class with one implementation.
- Inline by default. Don't extract a single-caller function unless it clearly reads better. Passing context objects into private helpers is a smell. Extraction is my call.
- Wrap third-party SDKs in your own repository or service that maps to domain types, so SDK types never leak into UI or state code, unless the wrapper would be a pure 1:1 pass-through. When a flow spans two SDKs, wrap each and orchestrate from a higher-level repository.
- Don't pass styling into reusable components. Styling belongs at the call site and formatting belongs on the model.
- Prefer plain loops to dense nested collection expressions. Don't filter data defensively.
- Comments only for non-obvious domain constraints, kept short. Say what something *is*, never its change history. When behavior changes, don't append history to a comment; only edit it if it's now wrong. Never explain imports, codegen, or tooling.
- Use the newest language features the project's language version supports over the older long-hand forms. Each language doc's `Current language` section lists them. If the project's SDK is newer than the version that section was reviewed at, check the release notes it links.
- Group related constants in nested namespace classes, in every language (`AppDesign.spacing.md`, `Endpoints.coffee.random`).
- Dev and deploy tooling must run on both Windows and macOS. Prefer cross-platform scripts (e.g. Dart) to shell. If a shell script is unavoidable, ship a PowerShell version next to the POSIX one.

## Persisted state
- Changing a persisted or serialized shape (stored state, local DB, cached JSON, prefs, enum values used as keys or positions) can wipe user data. Confirm old data still loads, add a migration when needed, version the state, and store stable identifiers (names), not positions.

## Communication
- Lead with the direct answer. Keep it short and scannable, and expand only when asked.
- Explain the why and the trade-offs. Follow the codebase's existing patterns, and flag rather than silently diverge.
- Report real problems only. No naming trivia or nitpicks.
- Design docs and memories hold product/design decisions and general working rules only. No tooling events or one-off trivia.
- A decision log holds only current decisions. When a decision changes, rewrite its original entry in place. Never add an entry that supersedes, amends, or layers on an earlier one.
- When the work a superpowers spec or plan covers is complete, compact that doc in place. Cut finished checklists, step-by-step instructions, and code listings. Keep what was built, the decisions and why, any deviations from the plan, and where the code lives. Keep the file and its path so links still work.
- Never put secrets, tokens, or personal data into files, commits, or memory.
