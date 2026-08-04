# Sourdough Incubator — Software Specification (SDD)

*Derived from `requirements.md` v0.1. Spec draft v0.1.*

This document turns the **software-relevant** requirements into implementable specifications:
each spec has an interface, the behaviour/algorithm, config parameters with proposed defaults,
edge cases, and testable acceptance criteria. Requirement IDs (e.g. `CTRL-1`) are carried
through for traceability; the matrix in §12 maps every requirement to its spec(s).

Language/runtime assumption: **Python 3.11+ on a Raspberry Pi-class SBC**. Signatures below
are Python-flavoured but the logic is language-agnostic. Numeric defaults marked `‹cfg›` are
tunable and gather the "concrete numeric targets" open decision in one place (§11).

---

## 0. Scope boundary — what this spec does *not* cover

The following are **hardware / physical** and are intentionally excluded from software specs
(they appear only where software must *interface* with them):

- The foil heater, servo, ultrasound module, temperature probe, camera, wiring/PSU.
- The **independent hardware thermal cutoff** (a non-programmable last line of defence).
  Software must assume it exists but must not rely on it for normal safety (see `SPEC-SAFE-1`).
- The physical energy meter / smart plug. Software consumes its *reported* power only.
- Mechanical vent/flap geometry and thermal characterisation (software commands a position 0–1).

Everything else — including every sensor *driver*, correction, and the logic that reads
hardware — is in scope.

---

## 1. Architecture overview

Eight software modules plus one cross-cutting safety concern. Data flows one way from sensors
to actuators and to the UI; persistence and energy branch off the same signal bus.

```
                       ┌──────────────────────────────────────────────┐
   temp probe ───┐     │                 signal bus                    │
   ultrasound ───┼──▶ SPEC-ACQ ──(TempReading, HeightReading)──┬───────┤
                 │                                             │       │
                 │                                             ▼       ▼
                 │                                          SPEC-CTRL  SPEC-EST
                 │                                        (foil PWM,  (rise ratio/rate,
                 │                                         vent pos)   phase, feed detect)
                 │                                             │       │
   smart plug ─▶ SPEC-ENERGY                                   │       ▼
                 │                                             │    SPEC-STATE ⇄ durable store
                 ▼                                             │       │
              SPEC-DATA (time-series log) ◀────────all signals─┘       ▼
                 │                                                   SPEC-GUIDE
                 ▼                                                      │
              Grafana / TSDB                                           ▼
                                                        SPEC-OPS (phone UI, camera, OTA)

   SPEC-SAFE (watchdog + failsafe) wraps SPEC-CTRL and the whole process.
```

Design rule from the requirements' three time-scales is preserved in the module split:
`SPEC-CTRL` owns the **instant** loop, `SPEC-EST`/`SPEC-STATE` own the **cycle** horizon,
`SPEC-STATE`/`SPEC-DATA` own the **cross-cycle** horizon.

---

## 2. Shared data model

```python
from dataclasses import dataclass
from enum import Enum

@dataclass(frozen=True)
class TempReading:
    t: float          # unix seconds
    celsius: float
    valid: bool       # False if failed plausibility (SPEC-ACQ)

@dataclass(frozen=True)
class HeightReading:
    t: float
    raw_mm: float          # distance-derived height before temp correction
    height_mm: float       # temperature-corrected dough height above container base
    valid: bool
    temp_corrected: bool   # False if no valid temp was available to correct with

class Phase(str, Enum):
    UNKNOWN    = "unknown"      # boot / no baseline yet
    FED        = "fed"
    RISING     = "rising"
    PEAKED     = "peaked"
    COLLAPSING = "collapsing"
    OVERDUE    = "overdue"

class FeedSource(str, Enum):
    AUTO = "auto"
    MANUAL = "manual"

@dataclass
class FeedEvent:
    t: float
    source: FeedSource
    baseline_height_mm: float   # height captured just after feed = cycle baseline

@dataclass
class CycleRecord:
    cycle_id: str
    fed_at: float
    baseline_height_mm: float
    peak_height_mm: float | None
    peaked_at: float | None
    time_to_peak_s: float | None
    max_rise_rate: float | None      # mm/h
    ended_at: float | None
    controller_type: str             # "two_point" | "pid"  (see SPEC-DATA note)

@dataclass
class Baseline:
    # per-culture rolling stats over the last N completed cycles (SENSE-7)
    typical_peak_ratio: float        # peak_height / baseline_height
    typical_time_to_peak_s: float
    typical_rise_rate: float         # mm/h
    n_samples: int
```

All modules exchange only these types across boundaries; internal representations are private.

---

## 3. `SPEC-ACQ` — Sensor acquisition & conditioning
*Covers `SENSE-1`, `SENSE-2`, `NFR-2`, `NFR-3`.*

**Purpose.** Provide a fixed-rate stream of validated, temperature-corrected readings that all
downstream modules consume. This is the single place sensors are read.

**Interface.**
```python
class SensorAcquisition:
    def read_temperature(self) -> TempReading: ...
    def read_height(self, temp_c: float | None) -> HeightReading: ...
    def run(self, on_temp, on_height) -> None:   # spawns the sampling loop
        ...
```

**Behaviour.**
1. Sample temperature at `TEMP_SAMPLE_HZ` and height at `HEIGHT_SAMPLE_HZ` (`NFR-2`).
   Height sampling may be slower — the fermentation signal is slow.
2. **Temperature correction of ultrasound (`SENSE-2`).** Speed of sound in air
   `c(T) = 331.3 + 0.606·T` m/s. If the ultrasound module reports distance assuming a fixed
   `c_ref = c(ULTRASOUND_ASSUMED_C)`, correct:
   `distance_corrected = distance_raw · c(T_now) / c_ref`.
   If no valid temp is available, pass the raw value through with `temp_corrected=False`.
3. **Height derivation (`SENSE-1`).** `height_mm = CONTAINER_REF_MM − distance_corrected`,
   where `CONTAINER_REF_MM` is the sensor-to-container-base distance (calibrated once).
4. **Plausibility (`NFR-3`).** Reject readings outside `TEMP_VALID_RANGE` / `HEIGHT_VALID_RANGE`,
   NaN, or physically impossible jumps (`|Δ| > MAX_STEP` between consecutive samples). Rejected
   readings are emitted with `valid=False` and are **not** silently dropped — control and
   estimation decide how to react, and logging records the rejection.

**Config.**
| key | default `‹cfg›` | note |
|---|---|---|
| `TEMP_SAMPLE_HZ` | 1.0 | |
| `HEIGHT_SAMPLE_HZ` | 0.2 | one reading / 5 s |
| `ULTRASOUND_ASSUMED_C` | 20.0 | datasheet reference |
| `TEMP_VALID_RANGE` | (0, 60) °C | |
| `HEIGHT_VALID_RANGE` | (0, CONTAINER_REF_MM) | |
| `MAX_STEP` (height) | 30 mm/sample | outlier gate |

**Acceptance.**
- Given a temp step of +10 °C, corrected distance changes by the predicted ≈1.8 % and matches a
  fixed physical target to within the sensor's own noise band.
- Injected out-of-range and NaN readings are flagged `valid=False`, never propagated as valid,
  and appear in the log as rejected.
- Loop periods are held to within ±10 % of the configured rate under normal load.

---

## 4. `SPEC-CTRL` — Temperature control (foil + vent)
*Covers `CTRL-1`…`CTRL-7`; heartbeats `SPEC-SAFE-1`.*

**Purpose.** Hold dough temperature at setpoint using PI(D) + PWM on the foil, with the servo
vent as a cooling actuator, coordinated so the two never fight.

**Interface.**
```python
@dataclass
class ControlOutput:
    foil_duty: float     # 0.0–1.0 PWM duty
    vent_pos: float      # 0.0 (closed) – 1.0 (fully open)
    integrator: float    # exposed for logging/anti-windup inspection
    saturated: bool

class TempController:
    def set_setpoint(self, c: float) -> None: ...      # CTRL-4
    def enable(self, on: bool) -> None: ...            # CTRL-5
    def step(self, temp: TempReading, dt: float) -> ControlOutput: ...
```

**Control law (`CTRL-1..3,6,7`).** A single PI(D) computes an unbounded command `u` from
`error = setpoint − temp`, which is **split-range** mapped to the two actuators:

```
u = Kp·error + Ki·∫error dt (+ Kd·d(error)/dt)          # PID; start with Kd = 0 (PI)

# Neutral band so the actuators don't fight (CTRL-7):
if error >  NEUTRAL_BAND:   foil_duty = clamp(u, 0, 1);  vent_pos = 0          # heat
elif error < -NEUTRAL_BAND: foil_duty = 0;               vent_pos = clamp(-u, 0, 1)  # shed heat
else:                       foil_duty = 0;               vent_pos = 0          # coast
```

- **Heat-only saturation & anti-windup (`CTRL-2`).** Foil clamps at duty 0 when cooling is
  needed. Use **conditional integration**: freeze the integrator when the *commanded* actuator is
  saturated and `error` would drive it further into saturation; otherwise integrate normally.
  Because the vent gives real (if limited) cooling authority, the integrator may keep working
  while venting — this is the point of `CTRL-6/7` relaxing the pure heat-only penalty.
- **Asymmetric tuning (`CTRL-3`).** Default gains are deliberately conservative for a plant that
  heats fast and cools slowly (`‹cfg›`, tune on the rig). Ship with derivative off.
- **Setpoint change (`CTRL-4`).** Bumpless: on setpoint change do **not** reset the integrator,
  and compute the derivative on measurement (not on error) to avoid a derivative kick.
- **Enable/disable (`CTRL-5`).** When disabled: `foil_duty = 0`; vent goes to
  `VENT_DISABLED_POS` (default *open* — safe cooling default). Integrator held.
- **Watchdog heartbeat.** Every successful `step()` pets the `SPEC-SAFE` watchdog.

**Simplest-first note (from requirements).** The split-range above *is* the "second saturating
output on the same PI error" first cut. Anything fancier (independent vent PID, feed-forward) is
future work.

**Config.**
| key | default `‹cfg›` |
|---|---|
| `CONTROL_PERIOD_S` | 2.0 |
| `Kp, Ki, Kd` | tune on rig; start (0.4, 0.01, 0.0) |
| `NEUTRAL_BAND` | 0.15 °C |
| `SETPOINT_DEFAULT` | 26 °C |
| `VENT_DISABLED_POS` | 1.0 (open) |

**Acceptance (`CTRL` acceptance in source).**
- Steady-state temperature holds within `±STEADY_BAND` (default **±0.3 °C**) with no sustained
  overshoot after a setpoint change.
- On a forced overheat excursion, the vent opens and temperature returns to band **faster** than
  a control run with the vent disabled (passive cooling), on the same rig.
- With cooling demanded for ≥5 min, the integrator does not wind up: on return to band there is
  no anti-windup overshoot.

---

## 5. `SPEC-EST` — Fermentation estimation
*Covers `SENSE-3`…`SENSE-7`.*

**Purpose.** Turn the height stream into the cycle-scale signals: rise ratio, rise rate, phase,
feed events, and the per-culture baseline. This is the core novelty.

**Interface.**
```python
@dataclass
class Estimate:
    t: float
    height_mm: float
    rise_ratio: float     # height / baseline  (SENSE-3)
    rise_rate: float      # mm/h, smoothed     (SENSE-4)
    phase: Phase          # SENSE-5
    peak_height_mm: float | None
    time_since_peak_s: float | None

class Estimator:
    def update(self, h: HeightReading, temp_c: float) -> Estimate: ...
    def submit_feed_marker(self, source: FeedSource) -> None: ...   # SENSE-6 manual/confirm
    def pending_feed_candidate(self) -> FeedEvent | None: ...       # SENSE-6 auto (needs confirm)
```

**Algorithms.**
- **Rise ratio (`SENSE-3`).** `rise_ratio = height_mm / baseline_height_mm`, baseline = height at
  the current cycle's feed event. Undefined (→ `UNKNOWN` phase) until a baseline exists.
- **Rise rate (`SENSE-4`).** EMA-smooth the height (`α = HEIGHT_EMA_ALPHA`), then finite-difference
  over `RATE_WINDOW_S` and express in mm/h. Ignore `valid=False` samples.
- **Phase state machine (`SENSE-5`).** Hysteresis on rate thresholds prevents chatter:

  | from | to | condition |
  |---|---|---|
  | FED | RISING | `rise_rate ≥ RISE_ON` sustained `T_CONFIRM`, or `rise_ratio ≥ RISE_RATIO_MIN` |
  | RISING | PEAKED | `rise_rate ≤ PEAK_EPS` after being positive **and** `rise_ratio ≥ PEAK_RATIO_MIN`; record `peak_height`, `peaked_at` |
  | PEAKED | COLLAPSING | `rise_rate ≤ COLLAPSE_ON` (negative) or `height ≤ peak·(1−COLLAPSE_FRAC)` |
  | COLLAPSING | OVERDUE | `time_since_peak ≥ OVERDUE_AFTER_PEAK` or `height ≤ peak·OVERDUE_FRAC` sustained |
  | *any* | FED | confirmed feed event (reset baseline, peak, timers, new `cycle_id`) |

- **Feed detection (`SENSE-6`).** Candidate when height drops `≤ −FEED_DROP_MM` over `FEED_WINDOW_S`
  **and** settles to `≤ baseline·FEED_RESET_FRAC`. Default policy = **auto-detect with user
  confirm** (the requirement's recommended v1): a candidate is surfaced via
  `pending_feed_candidate()` and only commits on `submit_feed_marker(...)` or after
  `AUTO_CONFIRM_TIMEOUT_S` if `AUTO_CONFIRM=True`. A purely manual marker is always accepted.
- **Per-culture baseline (`SENSE-7`).** On cycle completion, push `(peak_ratio, time_to_peak,
  max_rise_rate)` into a rolling window of the last `BASELINE_WINDOW_RUNS` cycles and recompute
  `Baseline` (median is more robust than mean here). Persisted via `SPEC-STATE`.

**Config.**
| key | default `‹cfg›` |
|---|---|
| `HEIGHT_EMA_ALPHA` | 0.3 |
| `RATE_WINDOW_S` | 300 |
| `RISE_ON` / `COLLAPSE_ON` | +2 / −2 mm/h |
| `RISE_RATIO_MIN` | 1.1 |
| `PEAK_EPS` | 0.5 mm/h |
| `PEAK_RATIO_MIN` | 1.4 |
| `COLLAPSE_FRAC` | 0.10 |
| `OVERDUE_AFTER_PEAK` | 6 h |
| `OVERDUE_FRAC` | 0.6 |
| `FEED_DROP_MM` / `FEED_RESET_FRAC` | 15 mm / 0.5 |
| `AUTO_CONFIRM` | False (surface, wait for confirm) |
| `BASELINE_WINDOW_RUNS` | 5 |

**Acceptance.**
- On logged reference runs, detected `peaked_at` is within `±PEAK_TOL` (default **±15 min**) of the
  hand-labelled true peak.
- A simulated feed (sharp drop + reset) raises exactly one candidate; phase resets to FED only on
  confirmation.
- Rate is stable (no phase chatter) under injected ±1 mm sensor noise.

---

## 6. `SPEC-STATE` — State & persistence
*Covers `STATE-1`…`STATE-5`, `NFR-4`.*

**Purpose.** Hold the durable truth of the culture across restarts and drive comparison logic.

**Interface.**
```python
class StateStore:
    def time_since_feed(self, now: float) -> float: ...          # STATE-1
    def current_phase(self) -> Phase: ...                        # STATE-2 (persisted)
    def record_phase(self, phase: Phase, t: float) -> None: ...
    def append_feed(self, event: FeedEvent) -> None: ...         # STATE-5
    def baseline(self) -> Baseline | None: ...                   # STATE-4 input
    def can_prompt_feed(self, now: float) -> bool: ...           # STATE-3 guard
    def recover(self) -> None: ...                               # NFR-4
```

**Behaviour.**
- **Persistence (`STATE-2`).** Phase, `last_feed_time`, active `cycle_id`, `Baseline`, and the
  feed log live in durable storage (SQLite is sufficient and file-atomic). Every state change is
  committed synchronously so a power cut loses at most the last uncommitted tick.
- **Prompt guard (`STATE-3`).** `can_prompt_feed` is False for `MIN_FEED_PROMPT_INTERVAL` after a
  feed event and while phase ∈ {FED, RISING} (never say "feed me" to freshly-fed dough).
- **Baseline comparison (`STATE-4`).** Expose current-cycle metrics vs `Baseline` as ratios
  (`peak_ratio/typical`, `time_to_peak/typical`, `rise_rate/typical`) — consumed by `SPEC-GUIDE`
  4/5.
- **Feed log (`STATE-5`).** Append-only: `(t, source, baseline_height_mm)`.
- **Recovery (`NFR-4`).** On startup, load last committed state. If the store is missing/corrupt,
  enter a safe default: phase `UNKNOWN`, **heating disabled**, awaiting a fresh feed marker — never
  resume heating on ambiguous state.

**Config.** `MIN_FEED_PROMPT_INTERVAL` default 2 h `‹cfg›`.

**Acceptance.**
- Kill -9 the process mid-cycle; on restart phase, last-feed time and baseline are intact.
- No "feed me" prompt is emitted within `MIN_FEED_PROMPT_INTERVAL` of a feed or during FED/RISING.
- Corrupt store → process boots into disabled-heating safe state, logged.

---

## 7. `SPEC-GUIDE` — User guidance
*Covers `GUIDE-1`…`GUIDE-6`. Answers the three user questions.*

**Purpose.** Pure, deterministic functions from state → user-facing guidance. No I/O, fully unit-
testable. Each maps to a source question.

**Interface.**
```python
@dataclass
class Guidance:
    feed_now: bool           # GUIDE-1  "When feed?"
    ready_to_bake: bool      # GUIDE-2  "When bake?"
    acute_health: str        # GUIDE-3  "About to die?" (e.g. "ok"|"deflating"|"overdue")
    chronic_health: str      # GUIDE-4  "declining"|"stable"|"improving"
    environment: str         # GUIDE-5  "ok"|"too_warm"|"too_cold"
    mood: str                # GUIDE-6  tamagotchi face key
    detail: dict             # numbers behind the mood, for the "advanced" view

def evaluate(est: Estimate, state, baseline: Baseline | None,
             temp_c: float, setpoint_c: float, now: float) -> Guidance: ...
```

**Rules.**
- **When to feed (`GUIDE-1`).** True if `phase ∈ {COLLAPSING, OVERDUE}` **or**
  `time_since_feed ≥ feed_interval(temp)`, gated by `STATE-3`. Temperature adjustment: warmer
  starter starves faster, modelled Q10-style
  `feed_interval(T) = BASE_FEED_INTERVAL / Q10^((T − T_REF)/10)` (`Q10≈2`, `T_REF=21 °C`).
- **When to bake (`GUIDE-2`).** True while `phase == PEAKED` (or RISING with
  `rise_ratio ≥ BAKE_RATIO` and `rise_rate ≤ PEAK_EPS`) — i.e. at/near peak activity.
- **Acute health (`GUIDE-3`).** `"ok"` while rising/peaked; `"deflating"` in COLLAPSING;
  `"overdue"` in OVERDUE, with `detail["overdue_h"]` = hours sat deflated.
- **Chronic health (`GUIDE-4`).** Compare to `Baseline`: flag `"declining"` if `peak_ratio`,
  `rise_rate`, or inverse `time_to_peak` fall below `CHRONIC_DECLINE_FRAC` of typical across the
  last runs; `"improving"` if above; else `"stable"`. Needs `n_samples ≥ 3` else `"stable"`.
- **Environment fit (`GUIDE-5`).** Trivial part: `|temp − setpoint|`. Behavioural part relative to
  baseline: `time_to_peak < WARM_FRAC·typical` **and** early collapse → `"too_warm"`;
  `time_to_peak > COLD_FRAC·typical` or fails to reach `PEAK_RATIO_MIN` → `"too_cold"`.
- **Mood/face (`GUIDE-6`).** Composite, **priority-ordered** (health/safety wins):

  | priority | mood key | trigger |
  |---|---|---|
  | 1 | `dying` | chronic `declining` **and** acute `overdue` |
  | 2 | `sick` | chronic `declining` |
  | 3 | `too_hot` / `too_cold` | environment read |
  | 4 | `hungry` | `feed_now` |
  | 5 | `ready` | `ready_to_bake` |
  | 6 | `happy` | RISING, healthy |
  | 7 | `sleepy` | FED, resting |

  `detail` always carries the raw numbers so the UI can offer a "show the sensors" toggle — the
  face is the default, not the only, view.

**Config.** `BASE_FEED_INTERVAL` 24 h; `Q10` 2.0; `T_REF` 21 °C; `BAKE_RATIO` 1.5;
`CHRONIC_DECLINE_FRAC` 0.8; `WARM_FRAC` 0.6; `COLD_FRAC` 1.5 — all `‹cfg›`.

**Acceptance.**
- On logged normal cycles, `feed_now` and `ready_to_bake` fire within `±PEAK_TOL` (**±15 min**) of
  the true peak.
- A run with peak_ratio at 70 % of baseline yields `chronic_health="declining"`.
- Given identical inputs, `evaluate` is pure and returns identical output (property test).

---

## 8. `SPEC-DATA` — Logging, storage & monitoring
*Covers `DATA-1`…`DATA-4`. Enabler for the digital-twin outlook.*

**Purpose.** Record every signal for live monitoring, post-run review, and future model training.
Start logging **immediately**, including on the legacy two-point controller, to capture the
"before" baseline.

**Interface.**
```python
class Logger:
    def log_tick(self, sample: dict) -> None: ...   # one row per control period
    def log_event(self, kind: str, payload: dict) -> None: ...  # feed, phase change, fault
```

**Schema (`DATA-1`).** One time-series measurement `tick` with tags/fields:
`t, temp_c, setpoint_c, foil_duty, vent_pos, integrator, height_raw_mm, height_mm, rise_ratio,
rise_rate, phase, power_w, cycle_id, controller_type`. The `controller_type` field (`two_point` |
`pid`) lets the two-point baseline and the PID runs share one schema so before/after is directly
comparable.

**Storage (`DATA-2`).** Durable, not in-memory: **InfluxDB or TimescaleDB** (both Grafana-native).
Writes are buffered and flushed at `FLUSH_INTERVAL`; on shutdown the buffer is flushed.

**Dashboards (`DATA-3`).** Grafana panels: (a) temp vs setpoint + duty + vent; (b) height +
rise_rate + phase bands; (c) feed/phase-change event annotations; (d) energy (from `SPEC-ENERGY`);
(e) cross-cycle baseline trend.

**Retention/export (`DATA-4`).** Raw ticks retained `RAW_RETENTION` (default 90 d), downsampled
rollups kept indefinitely. A stable, versioned **export to CSV/Parquet** keeps historical runs
queryable for cross-cycle analysis and future model training — the schema above is the contract
that must not break, so `FUT-1`'s digital twin can train on it later.

**Config.** `FLUSH_INTERVAL` 5 s; `RAW_RETENTION` 90 d `‹cfg›`.

**Acceptance.**
- A full run reconstructs from the store alone (no gaps > one tick under normal operation).
- Two-point and PID runs are distinguishable and comparable via `controller_type`.
- Export produces a schema-stable file that reloads without transformation.

---

## 9. `SPEC-ENERGY` — Energy accounting
*Covers `ENERGY-1`…`ENERGY-4`. Software side of the energy-saved story.*

**Purpose.** Turn reported power into per-run energy, normalise it for a fair comparison, and
compute savings vs the reference method.

**Interface.**
```python
class EnergyAccountant:
    def ingest_power(self, t: float, watts: float) -> None: ...     # ENERGY-1
    def run_energy_wh(self, cycle_id: str) -> float: ...
    def normalized(self, cycle_id: str) -> dict: ...                # ENERGY-3
    def savings_vs_reference(self, cycle_id: str) -> dict: ...
```

**Behaviour.**
- **Measure/log (`ENERGY-1`).** Integrate reported power over time (trapezoidal) to Wh per run;
  covers foil + servo + electronics because the meter sees the whole box. Persisted via
  `SPEC-DATA`.
- **Reference baseline (`ENERGY-2`).** A stored constant for the reference method (oven-with-light)
  under matched conditions, from measurement **or** a documented estimate. Config, not computed.
- **Normalisation (`ENERGY-3`).** Report both raw Wh/run **and** energy per unit thermal work,
  `E / ∫(T_box − T_ambient) dt` (Wh per °C·h above ambient), so a longer run or colder kitchen
  doesn't distort the comparison. Ambient comes from `T_AMBIENT` config or a second sensor if
  present; if absent, use the documented assumption and flag it in the output.
- **Savings.** `saved = normalized_reference − normalized_actual`, reported per run and cumulative.
  **Honesty note:** heat dumped through the vent (`CTRL-6`) is energy paid for, so aggressive
  venting shows up as *worse* numbers — report it straight; it's a genuine tension worth naming.
- **Surface (`ENERGY-4`).** Cumulative energy and savings feed the Grafana panel in `DATA-3`.

**Config.** `REFERENCE_WH_PER_DEGC_H` (measured/estimated); `T_AMBIENT` default 21 °C `‹cfg›`.

**Acceptance.**
- A known constant-power input integrates to the analytically expected Wh within meter tolerance.
- Two runs of different duration/ambient produce comparable *normalised* figures.
- A run with heavy venting shows measurably worse energy than an equivalent run without.

---

## 10. `SPEC-OPS` — Remote access & operations
*Covers `OPS-1`…`OPS-3`. Experience tier (P2).*

**Purpose.** Phone access to status/controls, a night-vision camera check, and safe remote
updates.

**Behaviour.**
- **Phone status/control (`OPS-1`).** A small responsive web app + HTTP/WebSocket API exposing the
  `Guidance` mood and read-outs, and controls for setpoint (`CTRL-4`) and enable (`CTRL-5`). All
  mutating endpoints require auth (`API_TOKEN`) and are rejected when the process is in a fault
  state.
  ```
  GET  /status        -> Guidance + latest readings
  POST /setpoint      -> {celsius}         (auth)
  POST /enable        -> {on: bool}        (auth)
  GET  /stream (ws)   -> live ticks
  ```
- **Camera stream (`OPS-2`).** On-demand MJPEG/WebRTC night-vision stream (`GET /camera`), started
  only while a client is watching to save power/bandwidth — the "baby monitor" for the dark box.
- **OTA updates (`OPS-3`).** Versioned releases applied atomically (container image pull or
  git-checkout + service restart), with a **post-update health check** and automatic **rollback**
  on failure. Updates must not run while heating is enabled unless the failsafe (`SPEC-SAFE`) is
  confirmed armed.

**Acceptance.**
- Status and controls work from a phone on the LAN; unauthenticated mutations are rejected.
- Camera stream renders a usable night-vision image and stops when no client is connected.
- A deliberately broken update rolls back and the prior version resumes.

---

## 11. `SPEC-SAFE` — Failsafe & non-functional
*Covers `NFR-1`…`NFR-4` (software portions).*

- **`SPEC-SAFE-1` Fail-safe heating (`NFR-1`).** A software watchdog is petted by every
  `SPEC-CTRL.step()`. If it isn't petted within `WATCHDOG_TIMEOUT` (default 3× `CONTROL_PERIOD_S`),
  or a required sensor reads invalid for `SENSOR_FAIL_TIMEOUT`, the watchdog forces `foil_duty = 0`
  and `vent_pos = 1` (open) and disables control. This is the *software* guarantee that the foil
  is never energised indefinitely; it is **in addition to**, not a replacement for, the independent
  hardware thermal cutoff (out of scope, §0).
- **`SPEC-SAFE-2` Sampling/loop periods (`NFR-2`).** The rates in §3/§4 are the documented,
  single-source-of-truth constants; changing them is a config change, not a code change.
- **`SPEC-SAFE-3` Plausibility (`NFR-3`).** Implemented in `SPEC-ACQ`; consumers must treat
  `valid=False` as "no reading", not as zero.
- **`SPEC-SAFE-4` Recovery (`NFR-4`).** Implemented in `SPEC-STATE.recover()`; ambiguous state
  boots with heating disabled.

**Acceptance.**
- Freezing the control thread de-energises the foil and opens the vent within `WATCHDOG_TIMEOUT`.
- Forcing the temp sensor invalid for `SENSOR_FAIL_TIMEOUT` triggers the same failsafe.
- Power-cycle recovers to a sane, logged state with no spurious heating.

---

## 12. Requirements traceability

| Requirement | Spec | Software? |
|---|---|---|
| CTRL-1..7 | SPEC-CTRL | yes |
| SENSE-1, SENSE-2 | SPEC-ACQ | yes |
| SENSE-3..7 | SPEC-EST | yes |
| GUIDE-1..6 | SPEC-GUIDE | yes |
| STATE-1..5 | SPEC-STATE | yes |
| DATA-1..4 | SPEC-DATA | yes |
| ENERGY-1 | SPEC-ENERGY (+ meter hardware) | software side |
| ENERGY-2 | SPEC-ENERGY (config/documented) | partial |
| ENERGY-3..4 | SPEC-ENERGY | yes |
| OPS-1..3 | SPEC-OPS | yes |
| NFR-1 | SPEC-SAFE-1 (watchdog) + hardware cutoff | software side |
| NFR-2 | SPEC-SAFE-2 | yes |
| NFR-3 | SPEC-ACQ / SPEC-SAFE-3 | yes |
| NFR-4 | SPEC-STATE / SPEC-SAFE-4 | yes |
| FUT-1..4 | *outlook — not specced; enabled by SPEC-DATA schema* | future |

**Hardware-only, no software spec:** foil, servo, ultrasound/temp/camera hardware, wiring/PSU,
the independent thermal cutoff, and the physical energy meter. Software interfaces to each are
covered above.

---

## 13. Open decisions — resolved as defaults

The requirements' open questions are handled so implementation can start; revisit as needed.

- **Feed detection:** spec'd as **auto-detect + user confirm** (`SPEC-EST`, `AUTO_CONFIRM=False`).
  Flip `AUTO_CONFIRM=True` for the "pet that just knows" demo once detection is trusted.
- **Numeric acceptance targets:** gathered as `‹cfg›` defaults — steady-state **±0.3 °C**, prompt
  window **±15 min**. All live in one config module (`SPEC-SAFE-2` single-source rule).
- **Priority scheme (P0–P2 vs MoSCoW):** unchanged — this spec preserves the source IDs and
  priorities; the sequencing in the requirements' §9 maps cleanly onto the module set (Milestone 1
  = ACQ+CTRL+DATA+ENERGY+SAFE, Milestone 2 = EST+STATE, Milestone 3 = GUIDE+DATA dashboards,
  Milestone 4 = OPS).
- **Conference framing:** out of software scope; noted only because it shifts emphasis between
  SPEC-OPS (maker demo) and SPEC-CTRL/SPEC-EST rigor (control-systems talk).
