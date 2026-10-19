# Prompt: start phase 0

Open a new Claude Code session in `C:\Users\laure\Documents\GitHub\sheettick`, select Sonnet 5.5, and paste:

---

We're starting **phase 0 (Foundations)** of SheetTick: a personal TickTick-style task app for Windows and Android,
built in Flutter, that uses my own Google Sheet as its database (local SQLite on each device, synced to the Sheet).

Before doing anything, read `CLAUDE.md`, then `docs/architecture.md`, `docs/sheet-schema.md`, `docs/sync-protocol.md`
and the P0 section of `docs/roadmap.md`. The work is tracked as GitHub issues #1–#10 in milestone
"P0 Foundations" on `lautmat/sheettick`; read them with `gh issue list --milestone "P0 Foundations"`.

Work through the issues in order (#1 → #10), one branch and one PR per issue (or per closely related pair),
closing the issue from the PR. Specifics:

1. **Toolchain (#1).** Flutter isn't installed yet. Check what's on the machine first (Visual Studio C++ workload,
   Android SDK, Java), then tell me exactly what you'll install and how (winget where possible) and wait for my OK.
2. **App (#2).** Generate the app inside `app/` with the command in `app/README.md`. Keep platforms to windows and android.
3. **Google Cloud (#3).** I do the console steps myself. Give me a short numbered checklist with exact values
   (project name, APIs, consent screen type, the single `drive.file` scope, Desktop client, Android client with package
   `com.lmathieu.sheettick` and the debug keystore SHA-1, which you compute for me). Ask me whether lmathieu.com is a
   Google Workspace domain before choosing Internal vs External. Tell me where to put the downloaded files in
   `app/secrets/`. Never commit secrets.
4. **Auth (#4), bootstrap (#5), drift schema (#6).** Follow the docs exactly. The schema doc is canonical.
5. **Sync engine (#7).** Pure Dart in `app/lib/core/sync/`, behind an interface so tests use a fake Sheets backend.
   The four conflict tests listed in `docs/sync-protocol.md` are mandatory and must pass before moving on.
6. **Minimal UI (#8) and CI (#9).**
7. **Exit check (#10).** Walk me through the Windows ↔ Android round trip and tell me what you verified yourself
   and what I need to check on my phone.

Rules: run `flutter analyze` and `flutter test` before every commit; conventional commit messages; if you hit a
decision that changes the schema, sync rules or stack, stop and ask me instead of improvising. Keep me posted with
a one-line status after each issue.

---

Notes for whoever starts it:
- The plan page with the full research is `docs/plan.html` (published copy: https://claude.ai/artifact/VzNiSZC713dkgwhyBeUvRV).
- Model selection is in the Claude app's model picker, not something the prompt can set.
