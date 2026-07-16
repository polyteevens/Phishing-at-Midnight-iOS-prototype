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
  does not render Core Haptics at all, so the rising tension pulse, the
  heartbeat, every per-decision stinger, and the mission-end/results beats
  will silently no-op there. Run on a real iPhone (Settings won't matter,
  just needs the Taptic Engine) to feel any of it. This is where "does it
  actually feel good" has to be judged — nothing here can be judged from a
  Preview or a description.

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

### Feel pass — combo, tension, hit-stop, rare event

| Knob | Current value | What it does |
|---|---|---|
| `Combo.tierThresholds` / `tierMultipliers` | 3/6/10 streak → ×1/×2/×3/×4 | Consecutive confident-correct calls before the speed-bonus multiplier steps up. A wrong call or a Flag resets both to base. |
| `Tension.pressureThreshold` / `criticalThreshold` | 30 / 70 | Breach-meter values where the whole presentation shifts mood — drone, vignette, heartbeat, haptics all key off these two numbers. |
| `Juice.hitStopDuration` | 0.08s | Tick-freeze on a catch, a mistake, or crossing into Critical. Rounds up to the nearest 100ms tick — can't currently go below one tick. |
| `Juice.shakeDuration` | 0.4s | Screen-shake decay length on a mistake or entering Critical. |
| `Juice.scorePopupDuration` | 0.9s | How long a flying "+N" takes to rise and fade. |
| `RareEvent.probabilityPerRun` | 0.3 | Chance a run gets a coordinated-attack burst at all — keep this low, it's a variable reward. |
| `RareEvent.triggerWindow` | 35%–70% of mission | Where in the run the burst can fire — never opens or closes the run. |
| `RareEvent.burstCount` / `burstArrivalStagger` / `burstClickTimerRange` | 3 emails / 0.5s apart / 6–11s | Shape of the burst: how many pending dangerous emails get pulled forward, how tightly clustered, how short their click timers get. |

The rare event reuses emails already drawn for the run (it pulls a few
not-yet-arrived dangerous ones forward and shortens their timers) rather than
adding new content — see `TriageEngine.triggerRareEvent()`.

The patient's name, her fate lines per outcome, and Supervisor Morales's
reactions per grade are copy, not numbers — edit them directly in
[NarrativeContent.swift](PhishingAtMidnight/Narrative/NarrativeContent.swift).

## Known gaps / things left for you

- **No audio assets ship yet.** `HapticsAudioService` looks up every sound by
  name in the bundle and silently no-ops if missing — drop matching files
  into `PhishingAtMidnight/Resources/`, add them to the target, and they
  start playing with no code changes. Names it looks for: `ambient_tension`
  (looping drone — also gets sped up/turned up via `.rate`/`.volume` as
  tension climbs, so one file covers all three tension states), `sfx_correct`,
  `sfx_mistake`, `sfx_combo_break`, `sfx_rare_event`, `sfx_result_success`,
  `sfx_result_fail` (each `.m4a`/`.mp3`/`.caf`). Every haptic beat these pair
  with (heartbeat, tension pulse, stingers, mission-end/results beats) is
  already fully wired and needs no assets — only the AVFoundation side is
  waiting on real audio.
- **Patient portrait is a hand-drawn vector placeholder**, not real
  illustration — see `PatientPortraitView.swift`. It's a simple SF Symbol +
  a heartbeat squiggle that dims when she isn't safe. Swap in real art later;
  the view's contract is just one `isSafe: Bool`, so no call site changes.
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

- Do the Briefing's ~10-15s and its six reveal lines (patient intro added
  this pass) feel like the right pace, or too slow to sit through on replay #2?
- Is 11 emails per run the right length for a ~10-minute daily session once
  Briefing + Results are included, or should `emailsPerRun` come down?
- Should "Flag for review" ever have a downstream consequence (e.g. a small
  time cost) rather than being purely a scoring hedge? Currently it's
  meter-neutral by design — see `TriageEngine.record(item:decision:autoClicked:)`.
- Does the combo multiplier actually change how you play, or is it just a
  number going up? If replaying doesn't feel meaningfully different chasing
  a streak vs. not, the tier thresholds/multipliers need reshaping, not just
  rebalancing.
- Is a 30% chance of the coordinated-attack event per run the right rarity —
  common enough to be a thing players talk about, rare enough to stay a
  surprise? Watch for it feeling like "every third run has an event" instead
  of a genuine variable reward.
- The hit-stop is currently one fixed tick (~100ms) regardless of how big the
  moment is — a real mistake and crossing into Critical both freeze for the
  same length. Worth differentiating once it's felt on-device.
