# Example Channel Configurations

**Author/Maintainer:** **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/

These are examples only. Actual Scale, Offset, terminal mode, and Y limits must come from the specific hardware and study protocol.

## Respiratory / physiology example

| Use | Device | Channel | Label | Unit | Scale | Offset | Terminal | Auto Y |
|---|---|---|---|---|---:|---:|---|---|
| ✓ | dev2 | ai0 | Flow | L/s | calibration-specific | calibration-specific | As validated | ✓ |
| ✓ | dev2 | ai1 | Diaphragm_EMG | mV | amplifier-specific | amplifier-specific | As validated | ✓ |
| ✓ | dev2 | ai2 | SCM_EMG | mV | amplifier-specific | amplifier-specific | As validated | ✓ |
| ✓ | dev2 | ai3 | Pressure | cmH2O | transducer-specific | transducer-specific | As validated | ✓ |

Do not copy placeholder calibration values into real experiments.

## Simple voltage bench test

For a known voltage reference:

| Channel | Label | Unit | Scale | Offset |
|---|---|---|---:|---:|
| ai0 | TestVoltage | V | 1 | 0 |

## Volts-to-millivolts display

If the source is directly represented in volts and desired display is mV:

```text
Scale  = 1000
Offset = 0
Unit   = mV
```

For an EMG amplifier with its own gain/output scaling, use the amplifier's documented conversion instead of automatically multiplying by 1000.

## Baseline/TARE example

```text
Baseline mean = +0.250 L/s
TareOffset    = -0.250 L/s
Expected mean after TARE ≈ 0 L/s
```

Calibration Scale/Offset remains unchanged.

## Suggested cable labels

```text
FLOW_OUT     -> NI AI0
EMG_DIAPH    -> NI AI1
EMG_SCM      -> NI AI2
PRESSURE_OUT -> NI AI3
```

Match identifiers in physical cable labels, recorder configuration, and lab setup sheet.

---

Examples maintained by **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/
