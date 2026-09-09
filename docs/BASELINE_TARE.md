# Baseline / TARE Workflow — V4.0.3

**Author/Maintainer:** **Vinay Shankar**  
**Email:** vinay@tfaworld.org  
**Website:** https://tfaworld.org/

## Purpose

TARE lets the investigator define the current resting/baseline level as zero without changing underlying channel calibration.

```text
Raw NI voltage
      ↓
× Scale + CalibrationOffset
      ↓
Calibrated engineering value
      ↓
+ TareOffset
      ↓
Final displayed/saved engineering value
```

Implemented equation:

```text
finalValue = rawVoltage × Scale + CalibrationOffset + TareOffset
```

## Why TARE is separate from calibration Offset

Calibration `Offset` belongs to the physical conversion from voltage to engineering units. TARE is a **session baseline correction**.

Keeping them separate means reusable calibration is not destroyed, new sessions can establish new baselines, and MAT metadata can report both terms independently.

## How V4.0.3 calculates TARE

For each selected channel, the recorder calculates the mean of the most recent baseline window before the new TARE is applied.

```text
BaselineMean = mean(recent calibrated samples)
TareOffset   = -BaselineMean
```

Example:

```text
Flow baseline mean = +0.437 L/s
TareOffset         = -0.437 L/s
New baseline       ≈ 0 L/s
```

## Recommended workflow

1. Configure channels and units.
2. Press **START**.
3. Wait for a stable baseline condition.
4. Click **BASELINE / TARE**.
5. Choose the baseline duration.
6. Select channels to zero.
7. Click **TARE SELECTED**.
8. Confirm `Zeroed mean` is approximately zero.
9. Observe live signal windows.
10. Begin the experimental task.

## Choosing baseline duration

Default: **1 second**.

Longer windows average more samples and are less sensitive to a single transient, but the correct duration depends on signal and protocol.

Examples:

- flow: verified no-flow/rest condition;
- pressure: appropriate zero-reference condition;
- force: unloaded/no-force state when scientifically appropriate;
- EMG: consider whether subtracting a mean voltage is meaningful for the processing method.

## EMG caution

Raw bipolar EMG often oscillates around approximately zero after appropriate amplification/high-pass characteristics. A DC mean TARE can remove a small offset, but does **not** replace proper EMG preprocessing, electrode checks, amplifier setup, filtering, rectification, normalization, or artifact handling.

## Clear TARE

Use **CLEAR SELECTED** to remove runtime TARE for selected channels. The signal returns to:

```text
rawVoltage × Scale + CalibrationOffset
```

## Persistence

TARE is intentionally **not stored as a reusable configuration value** across sessions.

Reusable configuration includes device/channel, label/unit, scale, calibration offset, terminal mode, Y-axis settings, and preferred baseline duration.

## Saved metadata

MAT output includes fields such as:

- `CalibrationOffset`
- `TareOffset`
- `BaselineMean_PreTare`
- `BaselineDuration_s`
- `TareUTC_ms`
- `OutputDefinition`
- author/contact/project provenance

## Protocol recommendation

Document:

- which channels are tared;
- the condition defining baseline;
- baseline duration;
- whether TARE is performed per participant, visit, trial, or hardware setup;
- when re-TARE is required.

---

Baseline/TARE implementation and documentation by **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/
