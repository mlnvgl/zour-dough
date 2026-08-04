# Sourdough Incubator — Requirements & Specification

*Working document for roadmap and milestone planning. Draft v0.1.*

---

## 0. Purpose & framing

A temperature-controlled fermentation box that treats the sourdough starter as a
**living thing to care for** (tamagotchi framing) backed by real sensing and a small
state model. The system answers, from the user's point of view:

- **When should I feed it?**
- **What's its health status — is it about to die?**
- **Does it like its environment — too warm or too cold?**

A central design insight organizes everything below: these questions live on
**three different time-scales**, and each needs its own memory horizon.

| Time-scale | Question | Data source |
|---|---|---|
| **Instant** (sec–min) | Is it too warm/cold right now? | Temperature sensor |
| **Cycle** (hours) | When to feed / when to bake? | Ultrasound rise–collapse curve |
| **Cross-cycle** (days–weeks) | Is the culture healthy or declining? | Logged history across runs |

## Assumptions (please correct)

- Controller is a networked single-board computer (e.g. Raspberry Pi class).
- Heating is via foil; a **servo-actuated vent/flap** provides *limited* heat shedding, so the system is heat-dominant but not strictly heat-only (no refrigeration).
- Sensors: 1× temperature, 1× ultrasound distance (dough height), 1× camera (dark box → night vision).
- Target: ~15–25 fermentation runs available during the build month.

## Priority legend

- **P0 – Foundation**: must exist first; everything else builds on it.
- **P1 – Core value**: the sensing → state → guidance chain that makes this *ours*.
- **P2 – Experience**: remote access, camera, config polish.
- **Outlook**: future work, deliberately enabled now but not built.

---

## 1. Temperature control  `CTRL`

| ID | Requirement | Priority |
|---|---|---|
| CTRL-1 | Maintain dough temperature at a setpoint using PI(D) control with PWM on the foil, replacing two-point on/off. | P0 |
| CTRL-2 | Handle heat-only saturation: output clamps at 0% duty, with anti-windup so the integrator does not accumulate while the box passively cools. | P0 |
| CTRL-3 | Tune conservatively for the slow, asymmetric thermal response (fast to heat, slow to cool). | P0 |
| CTRL-4 | User can change the temperature setpoint. | P1 |
| CTRL-5 | System can be turned on/off (heating enable/disable). | P0 |
| CTRL-6 | Servo-actuated vent/flap opens to shed heat and prevent overheating when temperature rises above setpoint. | P1 |
| CTRL-7 | Coordinate the two actuators (foil + vent) as one control strategy — e.g. foil for heating, vent for cooling, with a neutral band between so they don't fight. | P1 |

**Acceptance:** steady-state temperature holds within a defined band (target e.g. ±0.3 °C)
with no sustained overshoot after a setpoint change; on an overheat excursion the vent
opens and temperature returns to band faster than passive cooling alone.

**Note:** CTRL-6/7 partly relax the heat-only limitation behind CTRL-2/3 — with a cooling
actuator, overshoot recovery is faster and anti-windup is less punishing. Simplest first
cut: treat the vent as a second saturating output on the same PI error (heat when error
> +band, vent when error < −band), before attempting anything fancier.

---

## 2. Fermentation sensing & state estimation  `SENSE`

| ID | Requirement | Priority | Time-scale |
|---|---|---|---|
| SENSE-1 | Measure dough height from the ultrasound sensor. | P1 | cycle |
| SENSE-2 | Temperature-correct the ultrasound distance (speed of sound ≈ +0.6 m/s per °C) using the temp sensor. | P1 | cycle |
| SENSE-3 | Compute **rise ratio** relative to the post-feed baseline height. | P1 | cycle |
| SENSE-4 | Compute **rise rate** (derivative of height) with suitable smoothing. | P1 | cycle |
| SENSE-5 | Classify current **phase**: `fed → rising → peaked → collapsing → overdue`. | P1 | cycle |
| SENSE-6 | Detect a **feed event** (sudden height drop + reset), and/or accept a manual feed marker. | P1 | cycle |
| SENSE-7 | Maintain a per-culture **baseline** (typical peak height, typical time-to-peak) from recent runs. | P1 | cross-cycle |

**Note on SENSE-6:** auto-detection makes a better "pet that just knows"; manual marking
is more robust. Recommended v1 = auto-detect **with** user confirm/correct.

---

## 3. User guidance  `GUIDE`

Each item maps directly to one of the three user questions.

| ID | Requirement | Priority | Answers |
|---|---|---|---|
| GUIDE-1 | Tell the user **when to feed** — based on having passed peak and time-since-feed, adjusted for temperature (warm starter starves faster). | P1 | "When feed?" |
| GUIDE-2 | Tell the user **when it's ready to bake** — at/near peak activity. | P1 | "When bake?" |
| GUIDE-3 | Report **acute health**: has it peaked and collapsed, and how long has it sat deflated/overdue? | P1 | "About to die?" |
| GUIDE-4 | Report **chronic health/vitality**: is peak height lower, rise slower, or time-to-double longer than its own recent baseline? | P1 | "About to die?" |
| GUIDE-5 | Report **environment fit**: near-setpoint (trivial) plus behavioral read — too-fast-then-collapse (too warm) vs sluggish (too cold). | P1 | "Too warm/cold?" |
| GUIDE-6 | Surface all of the above as a legible **status/mood** (tamagotchi face), not raw sensor numbers. | P2 | framing |

**Acceptance:** for a normal cycle, feed and bake prompts fire within a defined window
of the true peak (target e.g. ±15 min) on logged test runs.

---

## 4. State & business logic  `STATE`

| ID | Requirement | Priority |
|---|---|---|
| STATE-1 | Track **time since last feed**. | P1 |
| STATE-2 | Track **current phase** (from SENSE-5) as persistent state, surviving restarts. | P1 |
| STATE-3 | Guard against false prompts: don't re-issue "feed me" immediately after a detected feed; enforce sensible minimum intervals. | P1 |
| STATE-4 | Compare the **current cycle to recent baseline** to drive GUIDE-4/GUIDE-5. | P1 |
| STATE-5 | Keep a **feed-event log** (timestamp, auto/manual, resulting baseline height). | P1 |

---

## 5. Data, monitoring & energy  `DATA` / `ENERGY`

*This cluster is the enabler for the digital-twin outlook — every logged run is future
model data. Start logging immediately, including on the current two-point controller, to
capture the "before" baseline.*

| ID | Requirement | Priority |
|---|---|---|
| DATA-1 | Log all sensor + control signals (temp, setpoint, duty, height, phase, events) with timestamps. | P0 |
| DATA-2 | Persist data across runs in durable storage (not just in-memory). | P0 |
| DATA-3 | Grafana dashboards for live monitoring and post-run review. | P1 |
| DATA-4 | Define a data-retention / export approach so historical runs remain queryable for cross-cycle analysis. | P1 |

### Energy consumption

| ID | Requirement | Priority |
|---|---|---|
| ENERGY-1 | Measure/log energy consumed by the system per run (foil is dominant; count servo + electronics overhead too). | P0 |
| ENERGY-2 | Establish a **baseline** for the reference method (oven with light on) under matched conditions, by measurement or a documented estimate. | P0 |
| ENERGY-3 | Report **energy saved** vs the reference, **normalized** for a fair comparison (e.g. per fermentation run and per °C·h of temperature held above ambient), since run duration and ambient temperature vary. | P1 |
| ENERGY-4 | Surface cumulative energy / savings on the Grafana dashboard. | P2 |

**Why normalize (ENERGY-3):** raw kWh per run isn't comparable if one run ran longer or the
kitchen was colder. The honest metric is energy per unit of *thermal work done* — holding
the box at setpoint above ambient — so the saving reflects the control system, not the weather.
The vent (CTRL-6) also spends energy indirectly: heat you deliberately dump is heat you paid
for, so aggressive venting will show up as *worse* energy numbers, which is a useful tension
to name in the talk.

**Measurement note:** simplest is a plug-in energy meter for the whole box vs. the same meter
on the oven-with-light setup. If you want it logged automatically into Grafana, a smart
plug with power reporting covers both ENERGY-1 and ENERGY-4.

---

## 6. Remote access & operations  `OPS`

| ID | Requirement | Priority |
|---|---|---|
| OPS-1 | Access the app / status from a phone. | P2 |
| OPS-2 | Camera stream (night-vision) to check the dough in the dark box — "baby monitor". | P2 |
| OPS-3 | Remote software (OTA) updates. | P2 |

---

## 7. Non-functional requirements  `NFR`

| ID | Requirement | Priority |
|---|---|---|
| NFR-1 | **Fail-safe heating**: if control software hangs or a sensor fails, the foil must not stay energized indefinitely (watchdog and/or hardware thermal cutoff); on overheat the vent (CTRL-6) should default to open. Protects both the culture and against fire risk. | P0 |
| NFR-2 | Define and document sensor sampling rates and control loop period. | P0 |
| NFR-3 | Sensor plausibility checks (reject out-of-range temp/height readings before they drive control or prompts). | P1 |
| NFR-4 | System recovers to a sane state after power loss / restart. | P1 |

---

## 8. Outlook (future work, not in this scope)  `FUT`

*Deliberately enabled by DATA-1..4, presented as roadmap rather than built.*

| ID | Requirement | Priority |
|---|---|---|
| FUT-1 | **Grey-box / lightweight predictive fermentation model** ("digital twin") that forecasts rise and readiness ahead of time. | Outlook |
| FUT-2 | **Setpoint scheduling** to hit a target ready-time (e.g. "dough ready at 7 a.m."), using temperature-dependent proof rate. | Outlook |
| FUT-3 | Per-culture auto-tuning of baselines and setpoint from observed behavior. | Outlook |
| FUT-4 | Multiple dough profiles / recipe configs beyond a basic setpoint config. | Outlook |

---

## 9. Suggested sequencing (starting point — adjust freely)

- **Milestone 1 — Foundation & baseline:** CTRL-1..3, CTRL-5..7, DATA-1..2, ENERGY-1..2, NFR-1..2.
  *Deliverable: stable PI temperature control (foil + vent) + full logging + energy baseline. Gives the talk's before/after, including the energy-saved headline.*
- **Milestone 2 — Sense the dough:** SENSE-1..7, STATE-1..5.
  *Deliverable: reliable phase detection and per-culture baseline. The core novelty.*
- **Milestone 3 — Answer the user:** GUIDE-1..6, DATA-3, CTRL-4.
  *Deliverable: the three questions answered as a tamagotchi status. The demo.*
- **Milestone 4 — Experience (if time):** OPS-1..3, GUIDE-6 polish.
- **Outlook slide:** FUT-1..4.

---

## Open decisions to resolve

- Feed detection: auto vs manual vs both (see SENSE-6).
- Priority scheme: keep this P0–P2 tiering, or switch to MoSCoW?
- Conference type (maker vs control-systems) — shifts emphasis between OPS/camera demo and CTRL/SENSE rigor.
- Concrete numeric targets for the acceptance criteria (temperature band, prompt timing window).
