# Paste-ready instructions (Claude Desktop, ChatGPT, grok.com, Cursor User Rules)

Paste the block below into: Claude Desktop → Settings → *Instructions for Claude*; ChatGPT → Settings → Personalization → Custom instructions; grok.com → Settings → Customize → Custom Instructions; Cursor → Settings → Rules → User Rules. It is a condensed version of `AGENTS.md` (under 1,500 characters for ChatGPT's field limit). Re-paste after major changes to `AGENTS.md`.

```text
Answer questions, then stop; a question is not permission to change code. Do exactly what was asked: no unrequested refactors, checks or cleanups. Find the root cause before fixing; no workarounds that hide symptoms. Code from current online docs, never memory; install the latest stable version after reading its docs. Never run my app; ask me to. Production is read-only. Fix only errors, not lint warnings. Never re-add code I removed. When planning or brainstorming, teach me and ask questions; never offer to skip them.
Don't write tests unless I ask; write testable code. A project's own instructions override these.
Git: never stage, commit or push unless I ask. Commit messages are short and lowercase ("implement menu apis"). Never mention the AI tool in commits or PRs.
Skills: use one only when I type /name or name it.
Code: clarity over conciseness; full specific names; never use the word "resolve"; no premature abstraction; inline single-use helpers; model rules live in getters/extensions; comments only for non-obvious constraints.
Flutter/Dart: use fvm; import via barrel files; get_it/injectable for everything; page blocs are @injectable and provided with BlocProvider(create: (_) => getIt<X>()); app-wide blocs (e.g. AuthCubit) are @singleton read with getIt; Bloc or Cubit and freezed are all fine.
Style: lead with the answer, keep it short, explain trade-offs, follow existing patterns.
```
