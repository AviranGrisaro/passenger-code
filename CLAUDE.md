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

## Machine & shell facts (paid for once — don't re-derive them)

**A check tool that fails quietly reads as a real result, and this machine has four ways to do that (L-058, 2026-08-08).** Every one of them returned a clean-looking answer that was wrong, and each cost a real diagnosis: `pgrep -c xcodebuild` / `pgrep -c 'Simulator|CoreSimulator'` matched on short name only and reported **zero** while `xcodebuild` and a full simulator runtime were live, which turned a load-270 HALT into a "load has drained, resume" call (2026-08-07); `timeout` **does not exist here** — no coreutils, `(eval):1: command not found: timeout` — so a command you thought you bounded runs unbounded; a **zsh glob that matches nothing aborts the whole command**, so `ls *.xcodeproj *.xcworkspace` silently produced nothing when only the second glob missed; and L-048's Linear case was the same shape one layer up. **So: when a check returns "nothing", prove the tool works before believing it** — a positive control, or a second tool that reads the same fact a different way. Use `pgrep -f` (full path) or `ps -Ao pcpu,rss,comm -r | head`, never bare `pgrep -c <name>`; use `setopt null_glob` or one glob per command; don't reach for `timeout`.

**Load is not the resource that runs out first — swap is.** The 2026-08-07 23:28 HALT read `uptime` 270 with ~108MB free RAM; the real bottleneck was `vm.swapusage` at **7869M of 8192M used (96%)**, driven by a booted iOS 26.5 runtime's `mediaanalysisd` daemon pinned at **286% CPU** — a known simulator pathology that does not self-resolve by waiting, so something has to shut the runtime down. Read `vm.swapusage` beside `uptime` and `df -h /`, and treat a load reading taken once as a trough, not a trend: re-check before calling a HALT drained.

**A saturated machine doesn't slow the test suite down, it fabricates failures — and they look exactly like real ones (2026-08-08, PAS-62 follow-up).** A `PassengerTests` run with four other sessions' `xcodebuild` processes live (load 201/331, swap 10740M of 11264M = 95%) came back `** TEST FAILED **` with a 14-test `Failing tests:` list spanning `PassportWiringTests`, `PassportBundleInvariantTests`, `EventHitTesterTests` and more. None of them were real: the log carried `malloc: *** error for object 0x116b28000: pointer being freed was not allocated` followed by `Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches`. The test *runner* had crashed and everything in flight got attributed as a failure. The same commit re-run on a drained machine passed 476/476. **So: before debugging any multi-suite failure, check whether the runner crashed** — `grep -E "malloc:|Restarting after unexpected exit"` over the log, and count concurrent builds with `pgrep -fl "usr/bin/xcodebuild" | grep -c "^[0-9]* /Applications/Xcode.app"`. Two tells that the failures are fake rather than yours: **a pure-function test is in the list** (here `EventHitTesterTests.emptySetMisses()`, which has no I/O, no concurrency, and cannot legitimately fail), and **the failures cluster in suites your diff never touched**. Don't "fix" these — discard the run and re-run clean. Waiting is cheap next to a day spent debugging a phantom. Gate a run behind the other sessions finishing rather than piling on:

```bash
while [ "$(pgrep -fl 'usr/bin/xcodebuild' | grep -c '^[0-9]* /Applications/Xcode.app')" -gt 0 ]; do sleep 60; done
```

## Simulator facts (paid for once — don't re-derive them)

Hard-won facts about *this machine and toolchain*, not about any one role. **Add new ones here, not to your own agent file** — a fact filed in the file of whoever discovered it is a fact the next role pays for again (L-046, 2026-08-05: `designer.md` carried a partial version of the first item below while `qa`, which runs the most simulator passes, had none and lost four rounds of T-038/`PAS-29` to it).

- **The location-permission dialog survives a privacy grant on any simulator that has ever launched the app.** `simctl privacy <udid> grant location-always <bundle-id>` does not suppress it, and `terminate` does not clear it — a stale in-flight CoreLocation request persists at the springboard level. The order that works: **`simctl erase` → grant → first-ever install + launch.** T-038/`PAS-29` rounds 10–13 were BLOCKED on this; round 15 root-caused it and confirmed the fix with a UDID-scoped screenshot.
- **Neither simulator mechanism for forcing an accessibility content size works on this toolchain** (Xcode 17F113 / iOS 26.5): not the `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibility…` launch argument, and not `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large` — the latter *stores* the value (the getter echoes it back, it survives relaunch and a full reboot) and still never changes rendered text size anywhere, confirmed by screenshotting plain SpringBoard. Established live at T-038/`PAS-29`, re-confirmed at `PAS-51`, and previously documented only inside two test files' comments, which is why it was re-derived twice. **This does not make Dynamic Type untestable** — `.environment(\.dynamicTypeSize, …)` is the app's own environment value, so a launch-argument-gated override at the composition root renders the real view hierarchy at a real accessibility size with real, queryable frames. That is the supported route here; a source-string grep asserting a ceiling constant is a regression backstop, not a rendered check (`prds/time-slider/TRD.md` §9 row 5b, C15).
- **`simctl io screenshot` returns a settled frame**, so it cannot capture motion — animation evidence needs `recordVideo` + `ffmpeg`.
- **The interactive simulator-control MCP needs a human to approve a grant, so in an unattended run it is *absent*, not flaky.** "The user has not granted Claude access" in a scheduled/background session is not a retryable blocker and not grounds for BLOCKED — nobody is there to click it. Drive the app through XCUITest's own automation instead (a throwaway uncommitted test file, deleted before the session ends). Two `qa` sessions hit this hours apart on 2026-08-05; only one found the workaround, and the other left two P0 sub-checks uncaptured.

## Safety

- Location data is sensitive: never log it, cache it unencrypted, or send it further than the feature needs. No real user location in tests or fixtures.
- No secrets in code — Supabase config and keys via env/config file, never committed literals. `SupabaseConfig.plist` is gitignored.
- Destructive git ops (force-push, `reset --hard`, history rewrite) — ask first.
- A green build is not "done." Build and test evidence goes in the report, not just the claim.
- **Name the branch explicitly in every `git pull`/`push`/`fetch`.** Passenger uses two separate GitHub repos (`passenger-code`, `passenger-brain`), so the ambiguity that bit the old shared-remote setup is gone — but the habit stays.
