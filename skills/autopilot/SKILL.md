---
name: autopilot
description: Settle a goal with the user, then work on it unattended until it is verified done, keeping a progress doc current and a 10-minute restart job so network errors and context compaction don't stop the run. Manual only - run only when the user types /autopilot or names this skill.
disable-model-invocation: true
metadata:
  short-description: Work unattended until a goal is done
  author: Jacob Blankenship
---

# Autopilot

The user hands over a goal and walks away. Once the goal is settled, assume nobody is watching until it is verified done: no questions, no waiting, no turns that end with a plan or a promise.

Every global and project rule still applies. The goal can grant exceptions (running the app, committing, installing packages, network calls); anything it doesn't grant stays forbidden.

## Arguments

- `/autopilot <goal>`: settle that goal and start.
- `/autopilot`: take the goal from the current conversation.
- `/autopilot resume [<progress doc>]`: the restart job's prompt, or a fresh session picking up a run. Go to **Waking up**.

## 1. Settle the goal

This is the only time to talk to the user.

1. If the progress doc (default `docs/autopilot.md`, or the file the user names) already holds an unfinished goal, resume it. If the user gave a different goal, ask whether to replace it.
2. Draft, from the arguments or the conversation:
   - **Goal:** one or two sentences.
   - **What done looks like:** checkable items, each with how it will be verified (a command, a test run, a reproduction, a measurement).
   - **Grants:** the exceptions the work needs. List what the goal obviously requires and nothing more.
   - **Out of scope:** what this run won't touch.
3. If all of that is clear, state it in one short block and start. If anything material isn't (what done means, a grant the work needs), ask once: one round of up to four short questions, each with the default you'd take. Then start, even if some answers are defaults.

Autopilot can't approve its own permission prompts. If the session asks before each edit or command, say so once here: the run will stop at every prompt.

## 2. Write the progress doc

Before any other work. It is the run's memory: a compaction, a dropped connection or a fresh session must be able to resume from it alone. It holds the current state, not a log, so rewrite it in place.

```markdown
# Autopilot: <goal in a few words>

Resume with `/autopilot resume <path of this file>`.

**Status:** running | paused | done
**Restart job:** <job id> (session-only; recreate on resume if missing)

## Goal
## What done looks like
- [ ] <item> (verify: <how>)
## Grants
## Out of scope
## Done so far
## In progress
<the current step, and the exact next action>
## Open questions
- <question>. Context: <one line>. Assumed: <default> because <why>. Changing it means: <cost>.
## Decisions
- <decision>, because <evidence>.
## Attempts
- <candidate>: <result of the deciding check>. Saved at <path> | kept.
```

## 3. Start the restart job

Create a recurring job every 10 minutes whose prompt is `/autopilot resume <progress doc>`. In Claude Code that's `CronCreate` with `*/10 * * * *`. Write its id into the doc.

How it behaves, so you add nothing on top: it fires only while the session is idle, so it never interrupts work in progress; a failed request or a stalled turn leaves the session idle, and the job restarts the run. A recurring job can fire up to half its period late. It lives only in this session and expires after 7 days. In a tool with no scheduler, say so once in the doc and keep going in the current turn.

## 4. Work

Loop until done: take the next step from the doc, do it, verify it, then update the doc before starting the next. A step is anything you'd hate to lose: a finished piece, a finding, a decision, a test result, a new question. Update any project docs the step touched at the same time, never in a batch at the end. After a compaction, read the doc again before the next step; the summary may have dropped details.

Verify by running things: the existing tests, the analyzer, a reproduction against the live system, throwaway scripts in the scratchpad. Add tests to the repo only if the goal grants it.

Side agents follow the usual side-agent rules.

### Investigate before you hold a question

When something is unclear, answer it yourself first: read the code and the package source, read the live docs, run it, measure it. Hold a question only when it is genuinely the user's call: taste, priorities, product scope, cost, or anything irreversible or outward-facing.

A held question goes under **Open questions** with the default you took and what changing it would cost. Keep going on that default when it is cheap to undo; park only the work that would be expensive to redo, and carry on with everything else. Never open a question prompt during the run; it blocks until the user returns.

### Try candidates instead of guessing

When the evidence doesn't pick an approach, try several:

1. Define the check that decides first: what to run and what result counts as correct or better.
2. Build one candidate, run the check, and record the result under **Attempts**.
3. Save it so it can be restored (a `git diff` of the tracked files plus copies of any new files, under `<doc folder>/autopilot-attempts/<candidate>/`), then back it out fully.
4. Repeat for the next candidate. Only one candidate is ever in the working tree; no worktrees.
5. Restore the winner and record why it won under **Decisions**.

## Waking up

On `/autopilot resume`:

1. Read the progress doc before anything else. If it is `done` or `paused`, delete any restart job for it and stop.
2. Check the restart job with `CronList`. If it's missing (a new session, or the 7 days ran out), create it again and update the id in the doc. If there are duplicates, delete the extras.
3. Continue from **In progress**. Never re-plan from scratch.

## When the user comes back

A message from the user mid-run gets a direct answer, then the run continues. If it answers open questions, apply each answer: rewrite the decision in place, redo any work built on a different default, and remove the question. If they say stop or pause, delete the job, set the status to `paused` with the exact next action, and stop.

## Done

Done means every item under **What done looks like** is verified by running its check, not just written.

1. Make the final round of analyzer fixes (warnings and infos) in the code the run touched.
2. Delete the restart job.
3. Delete `autopilot-attempts/` unless an open question depends on a saved candidate.
4. Rewrite the doc to its final state with the status `done`.
5. Report briefly: what was built, the decisions and why, what needs the user's eyes, and the open questions, each as one short line with the default that was taken, so they can be answered now.
