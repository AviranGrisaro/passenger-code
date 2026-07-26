# passenger-code — Engineering Session Contract

Native iOS app for **Passenger** (real-time local-heatmap travel app). Swift 6 / SwiftUI, MapKit, Supabase. This file is the session contract for anyone touching this repo — human or agent. Read it, follow it.

Stack, folder structure, and build status live in [README.md](README.md) — don't duplicate that here, keep it current there instead.

Role-specific process (who builds what, in what order, how tasks move through review) lives in the agent definitions at `../.claude/agents/` (`ios-developer.md` for this repo, `ios-code-reviewer.md`, `qa.md`, `architect.md`; `developer.md`/`code-reviewer.md` cover the Supabase backend at `passenger-brain/database/`, not this repo). This file is the engineering rules underneath all of those roles.

## Scope gate (read before writing any feature code)

Passenger exists because the previous codebase built ten features the strategy forbids. Before implementing anything:

- It must trace to a PRD in `passenger-brain/prds/`, and that PRD must cite the line in `passenger-brain/strategy/passenger-strategy.md` authorizing it.
- **No social features of any kind** — no friends, no following, no posting, no presence, no profiles, no avatars.
- **No onboarding** — the app opens straight to the map plus the location permission prompt.
- Phase 2 (proximity) and Phase 3 (AI guide, shake-to-decide, points) are **parked**. Don't build toward them, don't leave hooks for them.

If a task asks for something outside this, stop and say so rather than building it.

## Engineering pillars (non-negotiable)

- **Ruthless simplicity.** The smaller solution wins — fewer files, fewer types, fewer steps — as long as it satisfies the PRD/TRD. Don't build for a feature that isn't specced yet.
- **Surgical changes.** Touch what the task requires. Don't refactor, rename, or restructure outside the task's scope in the same commit — flag it instead, don't just do it.
- **Fail fast, don't swallow errors.** Throw or propagate on a broken precondition instead of returning a silent default (`nil`, `[]`, a stale cache) that hides the failure downstream. Exception: **at system boundaries** — network responses, Supabase rows, MapKit/CoreLocation callbacks, user input — validate explicitly and handle the failure state on purpose. Boundary validation is not defensive programming; skipping it is how a malformed response becomes a crash three screens away.
- **Read before you write.** Never edit a file you haven't opened in this session. Match existing idioms, naming, and comment density rather than imposing a new style.
- **Types over runtime checks, where the type system actually proves it.** Prefer non-optionals, enums over stringly-typed state, and `Result` over runtime asserts — but that's for internal logic, not a substitute for boundary validation.
- **Strict concurrency is on (`complete`, Swift 6).** Fix data-race warnings properly — actor isolation, `Sendable` conformance. Don't reach for `@unchecked Sendable` or `nonisolated(unsafe)` to silence the compiler.

## Salvaging from the old codebase

The previous app is frozen at `github.com/AviranGrisaro/locali` (branch `main`). `passenger-brain/SALVAGE.md` inventories it with a per-file verdict.

- Pull a file with `git show <sha>:<path>` from a clone of the archive — don't re-add the old repo as a remote here.
- **Salvage leaf code only:** models, service clients, map/geo math, formatting, tag logic.
- **Never salvage** architecture, view hierarchies, state management, or navigation. Those are the reason for the rewrite.
- Anything salvaged gets read line by line and adapted to Swift 6 concurrency before it lands. Copy-paste without reading is how the rot comes back.

## Debugging protocol

When something's broken and you're not implementing a spec, work in this order — don't jump to a fix on a hunch:

1. **Prove it.** Get a stack trace, a concrete repro, or a failing test. "Seems broken" isn't a starting point.
2. **Isolate.** Strip away everything not implicated until one path remains.
3. **Form a hypothesis** for *why* it fails before touching code.
4. **Add the minimal logging/assertion needed to confirm it, then remove it** once the fix lands — no debug scaffolding in the diff.

## Safety

- Location data is sensitive: never log it, cache it unencrypted, or send it further than the feature needs. No real user location in tests or fixtures.
- No secrets in code — Supabase config and keys via env/config file, never committed literals. `SupabaseConfig.plist` is gitignored.
- Destructive git ops (force-push, `reset --hard`, history rewrite) — ask first.
- A green build is not "done." Build and test evidence goes in the report, not just the claim.
- **Name the branch explicitly in every `git pull`/`push`/`fetch`.** Passenger uses two separate GitHub repos (`passenger-code`, `passenger-brain`), so the ambiguity that bit the old shared-remote setup is gone — but the habit stays.
