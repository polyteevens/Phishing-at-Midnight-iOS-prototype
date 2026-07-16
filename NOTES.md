# NOTES

Running list of tunable knobs, open questions, and known gaps. This is the
prototype's dashboard — check here first before digging into code.

## First thing to do on a Mac

This whole project was written blind on Windows — no Xcode, no Simulator, no
compiler. Before trusting anything else in here:

1. Open `PhishingAtMidnight.xcodeproj` in Xcode.
2. Pick a signing team on the target (Signing & Capabilities) — it's currently
   unset (`DEVELOPMENT_TEAM = ""`), so Xcode will prompt.
3. Build for an iOS 17+ Simulator (⌘R). If anything fails to compile, that's
   the top-priority fix — everything below assumes a clean build.
4. Open each file's `#Preview` (every view has one) to sanity-check layout
   before running the full app.

If step 3 turns up compiler errors, they're almost certainly small — wrong
API label, a missing `Self.` qualifier, that kind of thing — since every file
was hand-checked for brace/paren balance and read through carefully, but none
of it has ever been run through `swiftc`.

## How to build & run

- Scheme: **PhishingAtMidnight**, target iOS 17.0+.
- Start screen → **Begin Shift** → Briefing (auto-advances, ~10-15s, or tap
  **Skip** if you've seen it before) → Triage (the actual game) → Results →
  **Replay** or **Back to Start**.
- On-device testing matters most for `HapticsAudioService` — the Simulator
  does not render Core Haptics at all, so the rising Breach/Disruption tension
  pulse and the mission-end beat will silently no-op there. Run on a real
  iPhone (Settings won't matter, just needs the Taptic Engine) to feel it.

## Tunable numbers — all in [GameConfig.swift](PhishingAtMidnight/Config/GameConfig.swift)

| Knob | Current value | What it does |
|---|---|---|
| `Meters.breachIncrementPerClick` | 20 | Breach meter gain per dangerous email that gets clicked (≈5 misses = loss) |
| `Meters.disruptionIncrementPerWrongQuarantine` | 25 | Disruption meter gain per legit email wrongly quarantined (≈4 = loss) |
| `Meters.failThreshold` | 100 | Either meter hitting this ends the run as a failure |
| `Timing.missionDuration` | 150s | Total shift length |
| `Timing.arrivalIntervalRange` | 4–9s | Gap between one email arriving and the next |
| `Timing.clickTimerRangeNormal` | 18–30s | Hidden countdown before a normal-difficulty dangerous email gets auto-clicked |
| `Timing.clickTimerRangeHard` | 10–18s | Same, for "hard" specimens |
| `PoolComposition.emailsPerRun` | 11 | How many specimens are drawn per run |
| `PoolComposition.baseHardRatio` / `hardRatioRampPerReplay` / `maxHardRatio` | 0.15 / 0.10 / 0.6 | How much of the dangerous share is "hard" specimens, ramping with lifetime replay count |
| `Scoring.flagScoreMultiplier` | 0.5 | Flag always scores at half credit vs. a correct confident call |
| `Scoring.speedBonusMaxPerDecision` / `speedBonusFullCreditWindow` | 5 pts / 6s | Speed bonus per correct call, full credit inside the window, decaying to 0 by 2x |
| `Scoring.timeRemainingBonusPerSecond` | 0.5 | Bonus for clearing the queue with time left |
| `Scoring.goldMaxMeterValue` / `silverMaxMeterValue` | 25 / 60 | Risk-Control grade cutoffs (against the worse of the two final meters) |

The very first thing worth tuning once this is playable on-device: whether
+20/+25 actually makes Quarantine-vs-Allow feel like a real gamble, or whether
one meter dominates the other. That tension is the whole game — see
`CLAUDE.md`'s closing section.

## Known gaps / things left for you

- **No audio asset ships yet.** `HapticsAudioService.playAmbient()` looks for
  `ambient_tension.m4a` (or `.mp3`) in the bundle and silently no-ops if it's
  missing. Drop a looping ambient track into `PhishingAtMidnight/Resources/`
  with that name, add it to the target, and it starts playing — no code
  changes needed.
- **App icon is a placeholder.** `AppIcon.appiconset/Contents.json` declares
  the modern single 1024×1024 universal slot but no image is included. Add
  one before archiving for TestFlight/App Store; Simulator/Debug builds don't
  need it.
- **The SwiftUI Pro agent skill review** (twostraws/swiftui-agent-skill)
  called for in `CLAUDE.md` was never run — this environment has no way to
  install third-party Claude Code skills or reach the internet during the
  build. Manual passes were made for deprecated APIs (no `ObservableObject`,
  no `NavigationView`, `.onChange(of:)` uses the iOS 17 two-parameter form,
  `ContentUnavailableView`/`.inspector`/`symbolEffect` are all iOS 17+) and
  for basic VoiceOver support (accessibility labels/hints on the inbox rows
  and meters, inbox rows use `Button` not a bare tap gesture). Worth running
  that skill for real once you're set up in Xcode.
- **project.pbxproj is hand-generated.** A small Node script (not part of
  this repo) walks `PhishingAtMidnight/` and deterministically regenerates
  the project file — that's how files were added across commits without ever
  opening Xcode. Once you've opened this in Xcode, just use Xcode normally
  (add files via the Project Navigator) — Xcode will maintain the project
  file correctly from that point on. You should never need the generator
  again.

## Open questions for you to decide once it's playable

- Do the Briefing's ~10-15s and its five reveal lines feel like the right
  pace, or too slow to sit through on replay #2?
- Is 11 emails per run the right length for a ~10-minute daily session once
  Briefing + Results are included, or should `emailsPerRun` come down?
- Should "Flag for review" ever have a downstream consequence (e.g. a small
  time cost) rather than being purely a scoring hedge? Currently it's
  meter-neutral by design — see `TriageEngine.record(item:decision:autoClicked:)`.
