# Sourdough Incubator — User Stories & Use Cases

*Companion to the requirements v0.1. Draft v0.1. Software-relevant behaviour only.*

This document describes the system from the **user's point of view**: who interacts with it,
what they want, and how the important interactions play out step by step. It has three parts:

1. **Actors** — who/what interacts with the system.
2. **User stories** — grouped into epics, each traced back to requirement IDs.
3. **Detailed use cases** — the important interactions, fully dressed with flows.

A UML **use case diagram** is embedded in §4.

---

## 1. Actors

| Actor | Type | Role |
|---|---|---|
| **Baker** | Primary (human) | The person caring for the starter. Sets the setpoint, reads status, confirms feeds, checks the camera, and looks at energy. |
| **Scheduler / Time** | Supporting (internal) | The clock that drives the system's autonomous behaviour on its three time-scales — the control loop, phase estimation, and periodic guidance checks. |
| **Energy Meter** | Supporting (external) | The smart plug / power meter that supplies power readings to the system. |
| **Monitoring (Grafana)** | Supporting (external) | Consumes the logged time-series for live and historical dashboards. |

> The **starter** itself is the *subject* the system observes and cares for — the "tamagotchi" —
> but it is not an actor: it doesn't invoke behaviour, it's sensed. It's the thing every use case
> is ultimately about.

---

## 2. User stories

Format: *As a [role], I want [capability], so that [benefit].* Each story lists its acceptance
signal and the requirement IDs it realises.

### Epic A — Keep it at the right temperature  `CTRL`

- **A1** As a baker, I want to set the target temperature, so that my starter ferments at the pace I choose.
  *Accept:* the new setpoint takes effect within one control period and survives a restart. — `CTRL-4`
- **A2** As a baker, I want to switch heating on and off, so that I control when the box is working.
  *Accept:* disabling drops foil duty to 0 and moves the vent to its safe default. — `CTRL-5`
- **A3** As a baker, I want the box to hold temperature steadily without big swings, so that fermentation is predictable.
  *Accept:* steady-state within ±0.3 °C, no sustained overshoot after a setpoint change. — `CTRL-1, CTRL-2, CTRL-3, CTRL-7`
- **A4** As a baker, I want the box to shed heat when it runs too warm, so that my starter isn't overheated.
  *Accept:* above setpoint the vent opens and temperature returns to band faster than passive cooling. — `CTRL-6`

### Epic B — Understand the starter  `SENSE` / `STATE`

- **B1** As a baker, I want the system to measure how much the dough has risen, so that it can reason about the cycle.
  *Accept:* temperature-corrected height, rise ratio and rise rate are produced continuously. — `SENSE-1..4`
- **B2** As a baker, I want it to know whether the starter is rising, peaked, or collapsing, so that its advice reflects reality.
  *Accept:* phase is classified and persists across restarts. — `SENSE-5, STATE-2`
- **B3** As a baker, I want feeds detected automatically but confirmable, so that it "just knows" without getting it wrong.
  *Accept:* an auto-detected feed is surfaced for confirmation; a manual marker is always accepted. — `SENSE-6`
- **B4** As a baker, I want it to learn my starter's normal, so that it can tell a healthy run from an off one.
  *Accept:* per-culture baseline (typical peak, time-to-peak, rate) is maintained over recent runs. — `SENSE-7, STATE-4`
- **B5** As a baker, I want it to remember where things stand after a power blip, so that a restart doesn't lose the cycle.
  *Accept:* phase, last-feed time and baseline reload after restart; ambiguous state boots with heating off. — `STATE-1, STATE-2, NFR-4`

### Epic C — Tell me what to do  `GUIDE`  *(the three questions)*

- **C1** As a baker, I want to be told **when to feed**, so that I don't have to guess.
  *Accept:* reminder fires when past peak / overdue or the temperature-adjusted interval has elapsed, and never right after a feed. — `GUIDE-1, STATE-3`
- **C2** As a baker, I want to be told **when it's ready to bake**, so that I catch peak activity.
  *Accept:* ready alert fires within ±15 min of the true peak on logged runs. — `GUIDE-2`
- **C3** As a baker, I want to know **whether it's about to die**, so that I can rescue it.
  *Accept:* acute (peaked-and-deflated, how long) and chronic (declining vs its own baseline) health are both reported. — `GUIDE-3, GUIDE-4`
- **C4** As a baker, I want to know **if it's too warm or too cold**, so that I can adjust its environment.
  *Accept:* near-setpoint read plus a behavioural read (fast-then-collapse = warm, sluggish = cold). — `GUIDE-5`
- **C5** As a baker, I want a legible **mood** rather than raw numbers, so that status is glanceable.
  *Accept:* a single mood/face summarises health, hunger and comfort, with numbers available on demand. — `GUIDE-6`

### Epic D — Watch it and keep the record  `OPS` / `DATA`

- **D1** As a baker, I want to see status on my phone, so that I can check in from anywhere. — `OPS-1`
- **D2** As a baker, I want a night-vision camera view, so that I can look inside the dark box like a baby monitor. — `OPS-2`
- **D3** As a baker, I want live and historical dashboards, so that I can watch a run and review it afterwards. — `DATA-1, DATA-2, DATA-3`
- **D4** As a baker, I want past runs kept and exportable, so that history stays queryable for cross-cycle analysis. — `DATA-4`

### Epic E — Prove the energy saving  `ENERGY`

- **E1** As a baker, I want energy per run logged, so that I know what the box costs to run. — `ENERGY-1`
- **E2** As a baker, I want a reference baseline (oven-with-light), so that I have something to compare against. — `ENERGY-2`
- **E3** As a baker, I want savings reported **normalised** (per run and per °C·h above ambient), so that the comparison is fair across different run lengths and kitchen temperatures. — `ENERGY-3`
- **E4** As a baker, I want cumulative savings on the dashboard, so that the benefit is visible over time. — `ENERGY-4`

### Epic F — Keep it safe and current  `NFR` / `OPS`

- **F1** As a baker, I want the heater to fail safe if the software hangs or a sensor dies, so that my starter and my kitchen are protected.
  *Accept:* on watchdog timeout or persistent bad sensor, foil de-energises and the vent opens. — `NFR-1`
- **F2** As a baker, I want obviously wrong sensor readings ignored, so that a glitch doesn't drive bad control or false alerts. — `NFR-3`
- **F3** As a baker, I want the software updated remotely and safely, so that it improves without a trip to the box.
  *Accept:* atomic update with health check and automatic rollback on failure. — `OPS-3`

---

## 3. Detailed use cases

Fully-dressed for the interactions that carry the most behaviour or risk. Each notes the
`«include»`/`«extend»` relationships shown in the diagram.

### UC-1 — Regulate temperature
- **Primary actor:** Scheduler / Time · **Priority:** P0 · **Requirements:** `CTRL-1,2,3,6,7`, `NFR-2`
- **Goal:** Hold dough temperature at the setpoint using foil heat and the vent.
- **Preconditions:** Heating enabled; a valid temperature reading is available.
- **Trigger:** The control period elapses.
- **Main success scenario:**
  1. Read and validate the current temperature.
  2. Compute the error against the setpoint and the PI(D) command.
  3. Map the command to actuators: heat with the foil above the neutral band, hold in the band.
  4. Apply the foil PWM duty.
  5. Heartbeat the fail-safe watchdog.
  6. Emit all signals to logging.
- **Extensions / alternates:**
  - *3a. Temperature is above setpoint (too warm):* command the vent open proportionally instead of heating — `CTRL-6`. `«extend» Shed heat via vent`.
  - *1a. Temperature reading invalid:* skip actuation this tick, hold last safe output; if invalid persists → `«extend» UC-7 Enforce fail-safe`.
  - *2a. Cooling demanded and foil saturated at 0 %:* freeze the integrator (anti-windup) so it doesn't accumulate while the box passively cools — `CTRL-2`.
- **Postconditions:** Actuators reflect the new command; the tick is logged; watchdog is fresh.

### UC-2 — Detect and confirm a feed
- **Primary actors:** Scheduler / Time (detect), Baker (confirm) · **Priority:** P1 · **Requirements:** `SENSE-6`, `STATE-5`
- **Goal:** Recognise that the starter was fed and reset the cycle baseline correctly.
- **Preconditions:** Height sensing active.
- **Trigger:** A sharp height drop that settles near the empty/baseline level.
- **Main success scenario:**
  1. System detects the drop-and-settle signature and raises a **feed candidate**.
  2. System notifies the baker: "Looks like you just fed — confirm?"
  3. Baker confirms.
  4. System records a feed event (timestamp, source, new baseline height), resets phase to *fed*, and starts a new cycle. `«extend»` of this UC by *Confirm / mark feed*.
- **Extensions / alternates:**
  - *3a. Baker corrects (it wasn't a feed):* candidate is discarded; cycle continues unchanged.
  - *3b. No response within the confirm timeout:* candidate is auto-confirmed **only if** auto-confirm is enabled; otherwise it lapses.
  - *1a. Baker feeds and marks it manually first:* the manual marker is accepted directly and any later auto-candidate for the same event is suppressed.
- **Postconditions:** Feed log has one new entry; baseline and phase reset exactly once.

### UC-3 — Notify the baker it's time to feed
- **Primary actor:** Scheduler / Time · **Priority:** P1 · **Requirements:** `GUIDE-1`, `STATE-3` · **Answers:** *"When feed?"*
- **Goal:** Prompt a feed at the right moment, adjusted for temperature.
- **Preconditions:** A baseline and current phase exist. `«include» UC "Estimate fermentation phase"`.
- **Trigger:** Periodic guidance check.
- **Main success scenario:**
  1. System reads current phase and time-since-feed.
  2. System computes the temperature-adjusted feed interval (warmer → shorter).
  3. If past peak / overdue **or** interval elapsed, and the prompt guard allows it, raise a "feed me" prompt.
  4. Baker sees the prompt (mood turns *hungry*).
- **Extensions / alternates:**
  - *3a. A feed happened very recently:* the guard suppresses the prompt to avoid nagging freshly-fed dough — `STATE-3`.
  - *3b. Baker feeds in response:* flows into **UC-2**; prompt clears.
- **Postconditions:** At most one active feed prompt; guard interval respected.

### UC-4 — Notify the baker it's ready to bake
- **Primary actor:** Scheduler / Time · **Priority:** P1 · **Requirements:** `GUIDE-2` · **Answers:** *"When bake?"*
- **Goal:** Signal peak activity so the baker can use the starter at its best.
- **Preconditions:** Phase estimation running. `«include» "Estimate fermentation phase"`.
- **Trigger:** Phase reaches *peaked* (or near-peak: high rise ratio with rate near zero).
- **Main success scenario:**
  1. System detects the peak.
  2. System raises a "ready to bake" alert (mood turns *ready*).
  3. Baker bakes.
- **Extensions:**
  - *1a. Peak is missed and dough is already collapsing:* alert is downgraded to "past peak — feed soon" rather than "bake now."
- **Postconditions:** Ready alert fires within ±15 min of the true peak.

### UC-5 — Baker checks status and mood
- **Primary actor:** Baker · **Priority:** P1/P2 · **Requirements:** `GUIDE-3,4,5,6`, `OPS-1` · **Answers:** all three questions at a glance
- **Goal:** Understand the starter's state from a single glanceable view.
- **Preconditions:** App reachable. `«include» "Estimate fermentation phase"`.
- **Trigger:** Baker opens the app.
- **Main success scenario:**
  1. Baker opens status on the phone.
  2. System composes acute health, chronic health and environment fit into one **mood/face**.
  3. Baker reads the mood; optionally taps through to the underlying numbers.
- **Extensions:**
  - *2a. Chronic decline detected:* mood reflects *sick*/*dying* and the detail view explains which metric fell vs baseline — `GUIDE-4`.
  - *2b. Behavioural warm/cold signature:* mood shows *too hot*/*too cold* even when temperature is near setpoint — `GUIDE-5`.
  - *3a. Baker adjusts setpoint from here:* flows into "Set setpoint" — `CTRL-4`.
- **Postconditions:** No state change unless the baker acts.

### UC-6 — Report energy and savings
- **Primary actors:** Scheduler / Time, Energy Meter · **Priority:** P1/P2 · **Requirements:** `ENERGY-1,3,4`
- **Goal:** Show what the run consumed and how it compares, fairly, to the oven baseline.
- **Preconditions:** Energy meter reporting; a reference baseline is configured. `«include» "Log data"`.
- **Trigger:** Run completes (or dashboard refresh).
- **Main success scenario:**
  1. System integrates reported power into energy for the run.
  2. System normalises it per run and per °C·h held above ambient.
  3. System computes savings vs the reference and updates the dashboard.
- **Extensions:**
  - *2a. No ambient sensor:* the documented ambient assumption is used and flagged in the output.
  - *3a. Heavy venting during the run:* dumped heat shows up as worse energy — reported honestly, not hidden.
- **Postconditions:** Per-run and cumulative figures are persisted and visible.

### UC-7 — Enter fail-safe on fault
- **Primary actor:** Scheduler / Time (watchdog) · **Priority:** P0 · **Requirements:** `NFR-1, NFR-3, NFR-4`
- **Goal:** Never leave the foil energised when the system can't be trusted. `«extend»` of **UC-1**.
- **Preconditions:** System running.
- **Trigger:** Control loop misses its watchdog heartbeat, or a required sensor reads invalid past its timeout.
- **Main success scenario:**
  1. Watchdog detects the missed heartbeat / persistent bad sensor.
  2. System forces foil duty to 0 and drives the vent open.
  3. System disables control and logs the fault.
  4. On recovery/restart, the system reloads state and resumes only from a sane condition — `NFR-4`.
- **Extensions:**
  - *2a. Independent hardware thermal cutoff also trips:* out of software scope, but the two are complementary last lines of defence.
- **Postconditions:** Foil de-energised; vent open; fault recorded; safe restart path available.

---

## 4. Use case diagram

<svg viewBox="0 0 1180 860" xmlns="http://www.w3.org/2000/svg" font-family="'Segoe UI',Arial,sans-serif">
  <defs>
    <style>
      .box{fill:#f8fafc;stroke:#cbd5e1;stroke-width:1.5;}
      .uc-user{fill:#dbeafe;stroke:#3b82f6;stroke-width:1.6;}
      .uc-auto{fill:#dcfce7;stroke:#22c55e;stroke-width:1.6;}
      .uc-safe{fill:#fee2e2;stroke:#ef4444;stroke-width:1.6;}
      .uc-energy{fill:#fef9c3;stroke:#eab308;stroke-width:1.6;}
      .uct{font-size:12.5px;fill:#0f172a;text-anchor:middle;}
      .assoc{stroke:#475569;stroke-width:1.4;fill:none;}
      .rel{stroke:#64748b;stroke-width:1.4;stroke-dasharray:5 4;fill:none;}
      .rell{font-size:11px;fill:#475569;text-anchor:middle;font-style:italic;}
      .actor{stroke:#1e293b;stroke-width:1.8;fill:none;stroke-linecap:round;}
      .actort{font-size:13px;fill:#0f172a;font-weight:600;text-anchor:middle;}
      .title{font-size:19px;fill:#0f172a;font-weight:700;text-anchor:middle;}
      .sub{font-size:12.5px;fill:#64748b;text-anchor:middle;}
      .legt{font-size:12px;fill:#334155;}
    </style>
    <marker id="arr" markerWidth="10" markerHeight="8" refX="8" refY="3" orient="auto" markerUnits="strokeWidth">
      <path d="M0,0 L8,3 L0,6" fill="none" stroke="#64748b" stroke-width="1.4"/>
    </marker>
  </defs>

  <!-- Title -->
  <text x="590" y="30" class="title">Sourdough Incubator — Use Case Diagram</text>
  <text x="590" y="49" class="sub">Primary actor: Baker · Supporting actors: Scheduler, Energy Meter, Monitoring</text>

  <!-- System boundary -->
  <rect x="275" y="62" width="570" height="710" rx="10" class="box"/>
  <text x="560" y="82" class="uct" font-weight="700" fill="#334155">Sourdough Incubator System</text>

  <!-- ================= ASSOCIATIONS (drawn first, under nodes) ================= -->
  <!-- Baker (90,306) -> left column left edges (330,cy) -->
  <path class="assoc" d="M90,306 L330,90"/>
  <path class="assoc" d="M90,306 L330,162"/>
  <path class="assoc" d="M90,306 L330,258"/>
  <path class="assoc" d="M90,306 L330,350"/>
  <path class="assoc" d="M90,306 L330,442"/>
  <path class="assoc" d="M90,306 L330,534"/>
  <!-- Energy Meter (90,620) -> Measure energy left edge -->
  <path class="assoc" d="M90,620 L330,626"/>
  <!-- Scheduler (1055,300) -> right column right edges (835,cy) -->
  <path class="assoc" d="M1055,300 L835,95"/>
  <path class="assoc" d="M1055,300 L835,265"/>
  <path class="assoc" d="M1055,300 L835,360"/>
  <path class="assoc" d="M1055,300 L835,452"/>
  <path class="assoc" d="M1055,300 L835,544"/>
  <path class="assoc" d="M1055,300 L835,636"/>
  <path class="assoc" d="M1055,300 L835,728"/>
  <!-- Monitoring (1055,690) -> Log data right edge -->
  <path class="assoc" d="M1055,690 L835,728"/>

  <!-- ================= INCLUDE / EXTEND (dashed) ================= -->
  <!-- includes into Estimate phase (R2) -->
  <path class="rel" marker-end="url(#arr)" d="M530,258 L622,264"/>
  <text x="576" y="248" class="rell">&#171;include&#187;</text>
  <path class="rel" marker-end="url(#arr)" d="M625,452 C660,400 685,330 695,294"/>
  <text x="612" y="420" class="rell">&#171;include&#187;</text>
  <path class="rel" marker-end="url(#arr)" d="M625,544 C650,460 672,340 682,294"/>
  <text x="602" y="512" class="rell">&#171;include&#187;</text>
  <path class="rel" marker-end="url(#arr)" d="M625,636 C645,500 662,350 670,294"/>
  <text x="596" y="600" class="rell">&#171;include&#187;</text>
  <!-- Measure energy include Log data -->
  <path class="rel" marker-end="url(#arr)" d="M530,626 C575,660 590,700 622,724"/>
  <text x="556" y="678" class="rell">&#171;include&#187;</text>
  <!-- Enforce fail-safe extends Regulate temperature -->
  <path class="rel" marker-end="url(#arr)" d="M730,142 L730,125"/>
  <text x="775" y="136" class="rell">&#171;extend&#187;</text>
  <!-- Confirm/mark feed extends Detect feed event -->
  <path class="rel" marker-end="url(#arr)" d="M530,350 L622,358"/>
  <text x="576" y="338" class="rell">&#171;extend&#187;</text>

  <!-- ================= USE CASES ================= -->
  <!-- Left column (user goals) cx=430 rx=100 -->
  <ellipse cx="430" cy="90"  rx="100" ry="28" class="uc-user"/><text x="430" y="94" class="uct">Set setpoint</text>
  <ellipse cx="430" cy="162" rx="100" ry="28" class="uc-user"/><text x="430" y="166" class="uct">Turn on / off</text>
  <ellipse cx="430" cy="258" rx="100" ry="28" class="uc-user"/><text x="430" y="262" class="uct">Check status &amp; mood</text>
  <ellipse cx="430" cy="350" rx="100" ry="28" class="uc-user"/><text x="430" y="354" class="uct">Confirm / mark feed</text>
  <ellipse cx="430" cy="442" rx="100" ry="28" class="uc-user"/><text x="430" y="446" class="uct">View camera stream</text>
  <ellipse cx="430" cy="534" rx="100" ry="28" class="uc-user"/><text x="430" y="538" class="uct">View energy &amp; savings</text>
  <ellipse cx="430" cy="626" rx="100" ry="28" class="uc-energy"/><text x="430" y="630" class="uct">Measure energy</text>

  <!-- Right column (autonomous / system) cx=730 rx=105 -->
  <ellipse cx="730" cy="95"  rx="105" ry="28" class="uc-auto"/><text x="730" y="99" class="uct">Regulate temperature</text>
  <ellipse cx="730" cy="170" rx="105" ry="28" class="uc-safe"/><text x="730" y="174" class="uct">Enforce fail-safe</text>
  <ellipse cx="730" cy="265" rx="105" ry="28" class="uc-auto"/>
    <text x="730" y="261" class="uct">Estimate</text><text x="730" y="277" class="uct">fermentation phase</text>
  <ellipse cx="730" cy="360" rx="105" ry="28" class="uc-auto"/><text x="730" y="364" class="uct">Detect feed event (auto)</text>
  <ellipse cx="730" cy="452" rx="105" ry="28" class="uc-auto"/><text x="730" y="456" class="uct">Send feed reminder</text>
  <ellipse cx="730" cy="544" rx="105" ry="28" class="uc-auto"/><text x="730" y="548" class="uct">Send bake-ready alert</text>
  <ellipse cx="730" cy="636" rx="105" ry="28" class="uc-auto"/><text x="730" y="640" class="uct">Assess health</text>
  <ellipse cx="730" cy="728" rx="105" ry="28" class="uc-auto"/><text x="730" y="732" class="uct">Log data</text>

  <!-- ================= ACTORS ================= -->
  <!-- Baker -->
  <g class="actor"><circle cx="90" cy="278" r="11"/><line x1="90" y1="289" x2="90" y2="323"/><line x1="72" y1="300" x2="108" y2="300"/><line x1="90" y1="323" x2="76" y2="346"/><line x1="90" y1="323" x2="104" y2="346"/></g>
  <text x="90" y="364" class="actort">Baker</text>
  <!-- Energy Meter -->
  <g class="actor"><circle cx="90" cy="592" r="11"/><line x1="90" y1="603" x2="90" y2="637"/><line x1="72" y1="614" x2="108" y2="614"/><line x1="90" y1="637" x2="76" y2="660"/><line x1="90" y1="637" x2="104" y2="660"/></g>
  <text x="90" y="678" class="actort">Energy Meter</text>
  <!-- Scheduler -->
  <g class="actor"><circle cx="1055" cy="272" r="11"/><line x1="1055" y1="283" x2="1055" y2="317"/><line x1="1037" y1="294" x2="1073" y2="294"/><line x1="1055" y1="317" x2="1041" y2="340"/><line x1="1055" y1="317" x2="1069" y2="340"/></g>
  <text x="1055" y="358" class="actort">Scheduler / Time</text>
  <!-- Monitoring -->
  <g class="actor"><circle cx="1055" cy="662" r="11"/><line x1="1055" y1="673" x2="1055" y2="707"/><line x1="1037" y1="684" x2="1073" y2="684"/><line x1="1055" y1="707" x2="1041" y2="730"/><line x1="1055" y1="707" x2="1069" y2="730"/></g>
  <text x="1055" y="748" class="actort">Monitoring (Grafana)</text>

  <!-- ================= LEGEND ================= -->
  <line x1="40" y1="808" x2="80" y2="808" class="assoc"/>
  <text x="88" y="812" class="legt">association</text>
  <line x1="230" y1="808" x2="270" y2="808" class="rel" marker-end="url(#arr)"/>
  <text x="278" y="812" class="legt">&#171;include&#187; / &#171;extend&#187;</text>
  <rect x="40" y="828" width="16" height="12" class="uc-user"/><text x="62" y="838" class="legt">user goal</text>
  <rect x="150" y="828" width="16" height="12" class="uc-auto"/><text x="172" y="838" class="legt">autonomous / system</text>
  <rect x="330" y="828" width="16" height="12" class="uc-safe"/><text x="352" y="838" class="legt">safety</text>
  <rect x="420" y="828" width="16" height="12" class="uc-energy"/><text x="442" y="838" class="legt">energy</text>
</svg>

*Solid lines are actor associations; dashed arrows are `«include»`/`«extend»`. Blue = baker-facing
goals, green = autonomous/system behaviour, red = safety, amber = energy. The diagram shows the
primary goals for legibility; a few minor stories (e.g. "Review past runs", "Update software") live
in §2 but are omitted from the drawing to keep it readable.*

---

## 5. Story → requirement coverage (quick map)

| Epic | Stories | Requirements covered |
|---|---|---|
| A — Temperature | A1–A4 | CTRL-1..7 |
| B — Understand | B1–B5 | SENSE-1..7, STATE-1,2,4, NFR-4 |
| C — Guidance | C1–C5 | GUIDE-1..6, STATE-3 |
| D — Watch/record | D1–D4 | OPS-1,2, DATA-1..4 |
| E — Energy | E1–E4 | ENERGY-1..4 |
| F — Safe/current | F1–F3 | NFR-1,3, OPS-3 |

*Not covered here (deliberately): hardware provisioning and the `FUT-*` outlook items, which are
future work rather than user-facing behaviour today.*
