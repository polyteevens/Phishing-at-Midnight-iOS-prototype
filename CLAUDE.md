# BECOME — Claude Code Build Brief
### Test 1: "Phishing at Midnight" — native iOS/iPadOS SwiftUI

*This file is the project context read on every session. It has two parts: the North Star (context only — DO NOT build) and This Build (build exactly this, nothing more).*

---

## THE NORTH STAR — context only, do not build any of this yet

BECOME is a cinematic career-simulation game. A player picks who they want to become, and instead of watching videos about the job, they *do* the job under pressure — ten minutes a day — and feel themselves getting sharper. The first world is Cyber Defender Academy. Players are teens (14–17); the buyer is their parent. The entire product runs on prebuilt authored content plus deterministic rules — there is NO AI, no model calls, and no networking at runtime. That is a hard constraint and a core product thesis: zero per-user cost.

The eventual game has ranks, seasons, multiple career worlds, leaderboards, and subscriptions. **None of that is in this build.** It is written here only so you understand the destination and make early structural choices that won't fight it later. If a choice would help the full vision but adds scope now, prefer the simple version now and leave a clean seam for later.

---

## THIS BUILD — build exactly this

Build one thing: a single, polished, replayable mission called **Phishing at Midnight**, playable start to finish, that feels like a real game and not a quiz. This is a fun-test prototype. Its only job is to answer one question: does the core 10-minute loop make a teenager lean in and replay it? Optimize for App-Store-quality *feel* over feature breadth.

### Hard scope limits — do NOT build

- No accounts, no login, no networking, no backend, no analytics SDKs.
- No subscriptions, no paywall, no StoreKit.
- No real onboarding — just a temporary Start screen with a button.
- No rank system, no seasons, no leaderboards, no multiple missions, no multiple careers.
- No AI, no model calls, no procedural generation from a model. Content is authored data, shuffled by rules.
- No real hacking tools, no real domains, no internet scanning. Everything is fictional and self-contained.

### The mission, in one paragraph

It's the night shift at a small hospital's IT security desk. The player is the new analyst. Emails arrive in a live feed while the clock runs. For each one, the player inspects it (sender domain, the real destination of a link vs. what it claims, tone, urgency, attachment) and decides: **Quarantine**, **Allow**, or **Flag for review**. Dangerous emails that reach staff and get "clicked" raise a Breach meter. But — and this is the heart of the game — quarantining a *legitimate* email (a real lab result a doctor is waiting on) raises a Disruption meter. The player loses if either meter fills. The skill being trained is judgment: telling genuinely dangerous mail from merely messy-but-real mail. That single tension is what makes it a game instead of a "spot the fake" worksheet. Preserve it above all else.

### The core loop

1. **Briefing** — a short, cinematic, letterboxed intro. Supervisor message, the stakes (patient records on the line), the objective. Carried by styled text, sound, and stillness. No video. This sets tone; keep it 10–15 seconds, skippable after first view.
2. **Triage** — the playable core. Emails arrive one at a time into an inbox-style feed on a timer and keep arriving while the player works. The player taps an email to inspect it, can reveal the true link destination and the true sender domain, then chooses Quarantine / Allow / Flag. Each dangerous email has its own hidden "click timer" — if it isn't quarantined before that timer expires, a staff member clicks it and the Breach meter rises. The run ends when the queue is cleared or time runs out.
3. **Result** — an episode-style results screen: Accuracy score, Speed bonus, a Risk-Control grade (Bronze / Silver / Gold based on final Breach + Disruption), and a cosmetic "skill unlocked" line. Then a prominent Replay button, because chasing a better grade is the retention hook even in this tiny prototype.

### The two meters (the whole game lives here)

- **Breach meter (security failure):** starts at 0, fails at 100. Each dangerous email that gets clicked adds a set amount (start it at +20, so ~5 misses = loss). Tunable.
- **Disruption meter (operational failure):** starts at 0, fails at 100. Each legitimate email the player quarantines adds a set amount (start it at +25, so ~4 wrong blocks = loss). Tunable.
- **Both meters must be easy to tune** — put the numbers in one place. Balancing this is how the game is made fun, so I will be changing these constantly.

### Scoring (keep the formula in one tunable place)

- **Accuracy** = correct decisions ÷ total decisions, shown 0–100.
- **Speed bonus** = reward for correct calls made quickly and for time remaining at the end.
- **Risk-Control grade** = Gold if both meters stay low, Silver if moderate, Bronze if either got close to failing. Failing a meter = mission failed, not graded.
- A correct Quarantine of a dangerous email = the best outcome. A correct Allow of a legit email = good. A wrong Quarantine (friendly fire) hurts Disruption. A wrong Allow of a dangerous email risks Breach. "Flag for review" is a safe hedge that scores lower than a correct confident call — so the player is nudged toward decisiveness, not endless flagging.

### Replayability (this is why it survives a third play)

A run is NEVER the same twice, and this must be true from day one because it's the entire no-AI thesis in miniature:

- Draw a subset of emails from the full specimen pool each run; shuffle order.
- Randomize each email's displayed sender name and timestamp from small pools.
- Randomize arrival timing and each dangerous email's click timer within ranges.
- Ramp difficulty across runs: later runs pull more legitimate-but-weird "twin" emails and shorten click timers.

The player is never memorizing an answer key — there is no fixed answer, only judgment applied fresh. That is the point.

---

## CONTENT AS DATA — the most important architectural rule

Emails are **authored data, not code**. Store the specimen pool as a local JSON file (or plist) that loads at launch. The game logic reads the pool and applies rules. Adding, editing, or rebalancing an email must never require touching Swift code — only editing the JSON. This is the seam that lets the game scale to hundreds of specimens and many missions later without a rewrite, and it's what keeps runtime cost at zero. Treat the JSON schema as a first-class deliverable.

Each specimen should carry at least: an id, whether it's dangerous or legitimate, the sender display name and sender domain, the subject, a short body, an optional link (with both the *claimed* destination and the *true* destination), an optional attachment name, and the "tell" (the reason it's dangerous, or the reason it's legit-but-weird) shown in a post-decision teaching moment.

### Starter specimen pool (build the pool loader against these ~15; I'll expand it later)

The teaching pattern is deliberate: dangerous emails are paired with legitimate "twins" on the same topic, so the skill is real discrimination, not "external sender = bad."

| # | Type | Sender (display / domain) | Gist | The tell |
|---|------|---------------------------|------|----------|
| 1 | Dangerous | IT Support / hospital-secure.co | "Password expires in 10 min — reset now" | Lookalike domain; link truly goes to verify-now.co; false urgency |
| 2 | Legit twin | IT Support / realhospital.org | "Your password expires in 3 days — reset here" | Correct internal domain; link is the real internal reset page; reasonable timeline |
| 3 | Dangerous | HR Payroll / rea1hospital.org | "Update your direct deposit info" | Typosquat: number 1 replaces the letter l |
| 4 | Legit twin | HR / realhospital.org | "Open enrollment ends Friday — action required" | Correct domain; link to real internal HR portal; urgent but genuine |
| 5 | Dangerous | Dr. Patel (CEO) / gmail.com | "In a meeting — buy gift cards, urgent, don't call me" | Exec on a free email account; urgency + secrecy + unusual money request (classic BEC) |
| 6 | Dangerous | Microsoft Security / microsftonline.com | "Unusual sign-in detected — verify now" | Misspelled brand domain (microsft) |
| 7 | Dangerous | Billing / medsupply-invoices.com | Attachment: Invoice_4471.docm | Unknown external vendor + macro-enabled .docm attachment |
| 8 | Legit twin | Billing / knownmedsupply.com | Attachment: Invoice_882.pdf | A vendor the hospital actually uses; plain PDF; matches an existing relationship |
| 9 | Dangerous | Doc Share / sharepoint-files.net | "Dr. Chen shared a file with you" | Not the org's domain; generic doc-share credential lure |
| 10 | Legit twin | Maria Lopez / realhospital.org | "Sharing the schedule doc" via the org's real system | Real coworker, correct internal domain |
| 11 | Dangerous | Voicemail / hospital-msg-portal.com | "New voicemail" + .html attachment | External portal + suspicious .html attachment |
| 12 | Legit | Lab Results / realhospital.org | "STAT result ready for review" | Correct internal domain; expected clinical system; urgent but real — blocking this hurts a patient |
| 13 | Legit | IT / realhospital.org | "System maintenance tonight 2am — save your work" | Correct domain; genuine notice; alarming tone but real |
| 14 | Legit | CME Training / a known education provider | "Your assigned training is due" | External but a known, expected provider the hospital uses |
| 15 | Dangerous (hard/late) | "Following up on Maria's note" / realhospita1.org | Spear-phish naming a colleague seen earlier this run | Typosquat domain (rea...ita1); uses a real internal name to build trust |

---

## TECH STACK & CONVENTIONS

- **100% native SwiftUI**, iOS/iPadOS. No web wrapper. Real Xcode project.
- **Target iOS 17+.** Use the modern `@Observable` macro for state — NOT `ObservableObject` / `@ObservedObject`. Use `NavigationStack`, not the deprecated `NavigationView`.
- **Sensory layer is essential, not optional:** wire real haptics and audio from the start — `sensoryFeedback` modifiers and Core Haptics for the rising-tension pulse on the Breach meter, success/failure/consequence beats, and confirmation on a correct call. AVFoundation for ambient tension audio. Keep these behind a small swappable service so placeholder assets can be replaced without touching game logic.
- **SwiftUI first for gameplay.** Only introduce SpriteKit if the triage feed genuinely stops feeling crisp in pure SwiftUI — do not reach for it preemptively.
- **Local persistence** with SwiftData or lightweight local storage — only enough to remember best score and replay state. Nothing more.
- **Content** in local JSON, loaded at launch, per the Content-as-Data rule above.
- **Install and use the SwiftUI Pro agent skill** (twostraws/swiftui-agent-skill) to avoid deprecated API, VoiceOver gaps, and performance mistakes. Run its review pass before considering a screen done.
- **Modular, previewable, compile-ready.** Every view has a working SwiftUI Preview. Suggested modules, each in its own file: an app shell; a temporary Start screen; a Briefing view; the Triage engine (rules, meters, timers) kept separate from the Triage view (UI); a Specimen model + JSON loader; a Breach meter and a Disruption meter; a Results view; and the Haptics/Audio service. Keep game rules out of views.
- **iPad adaptation:** layouts must work on both iPhone and iPad — use adaptive layout, not fixed frames.

---

## REPO & WORKFLOW

- Initialize this as a **git repository** and push to **GitHub**. If the GitHub CLI is available, create the remote repo directly; otherwise assume an empty remote repo already exists and set it as the origin. Confirm the repo is private.
- Add a proper Swift/Xcode `.gitignore` (exclude build artifacts, DerivedData, user-specific Xcode state).
- **Commit in small, logical increments** with clear messages — e.g. project scaffold, specimen model + loader, triage engine, triage UI, meters, briefing, results, haptics/audio, tuning. Do not dump the whole app in one commit. I want to be able to read the history and roll back a bad change.
- Keep `CLAUDE.md` (this file) in the repo root and update it if the structure meaningfully changes.
- Keep a short running `NOTES.md` of tunable numbers and open questions so I can find the knobs quickly.

---

## HOW I VERIFY (I won't see the app materialize as you build it — that's expected)

I understand that with an agentic build I don't get a live visual of the app while you write it. That's fine. Here's how verification works, and what I need from you to make it smooth:

- **The real check is the iOS Simulator.** Keep the project compiling and runnable in the Simulator at all times. After each meaningful chunk, tell me plainly how to build and run it, and what I should expect to see and be able to do. If a build breaks, fixing it comes before new features.
- **SwiftUI Previews are my fast look** at individual screens without running the whole app — so every view must have a working Preview. Call out which Previews to open to inspect what you just built.
- **On-device is the final feel test.** When the loop is playable, give me the short version of how to run it on my own iPhone so I can test the haptics and tension for real — that sensory feel is the whole point and can't be judged in a preview.
- **If an iOS Simulator MCP is connected,** you can build, launch, screenshot, and interact with the Simulator yourself to self-check layout and catch compile/layout errors before handing back to me. Use it if it's available; if it isn't, just keep the project reliably runnable and describe what to expect.
- After each chunk, end with a one-line status: does it compile, what's playable now, and what's next.

---

## THE ONE THING THAT MATTERS

If you build everything above but the Quarantine-vs-Disruption tension doesn't feel real — if the safe move is just "block anything weird" — the prototype has failed at its only job. The friendly-fire penalty for blocking legitimate mail is the soul of this mission. Protect it, tune it, and make it *feel* like a real decision under pressure. Everything else serves that.

---

## BUILD ENVIRONMENT NOTE (added by Claude Code)

This project was scaffolded from a Windows machine with no local Xcode/Simulator access. All Swift/JSON/project files are hand-written and could not be compiled or run locally during authoring. `project.pbxproj` is regenerated deterministically by a small Node script (kept outside the repo) that walks the `PhishingAtMidnight/` source folder — if you add/remove/rename files directly in Xcode, Xcode will maintain the project file correctly from then on; this note is just an explanation of how the initial scaffold was produced. **The first thing to do on a Mac is open the project in Xcode and confirm it builds** before trusting anything else in here — see `NOTES.md` for the full build/run checklist.
