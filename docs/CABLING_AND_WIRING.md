# Cabling, BNC Connections, Grounding, and Signal-Chain Guidance

**Author/Maintainer:** **Vinay Shankar**  
**Email:** vinay@tfaworld.org  
**Website:** https://tfaworld.org/  
**Repository:** https://github.com/vinayrshankar/NIDAQ

This guide explains the practical cable categories around an NI USB-6251 BNC setup. It does not replace the NI manual or source-instrument manual.

## Computer-to-DAQ cable

For USB 62xx devices such as the USB-6251, NI specifies a **Hi-Speed USB 2.0 cable with USB Type-A and Type-B connectors on opposite ends**.

```text
Computer USB Type-A  ───── Hi-Speed USB 2.0 ─────  USB Type-B on NI USB-6251
```

If the acquisition computer has only USB-C, use a high-quality adapter/cable solution that preserves normal USB data operation and validate it before research use.

## DAQ power cable

The USB data cable does not replace the USB-6251's external power requirement.

```text
AC mains ── NI/compliant AC adapter ── DC power connector ── NI USB-6251
```

Secure both USB and power cables against accidental movement.

## Analog BNC signal cables

For instruments with BNC analog outputs:

```text
Sensor/amplifier analog OUT ── BNC coax cable ── NI AI BNC input
```

Use one cable per independently acquired analog output unless the upstream device specifies another arrangement.

The exact BNC cable impedance/type should follow the source instrument and laboratory setup. Do not infer that every BNC-output source requires a 50-ohm termination; check the upstream instrument manual.

## Example 4-channel cable inventory

- 1 × USB 2.0 Type-A-to-Type-B cable;
- 1 × correct NI USB-6251 power supply;
- 1 × BNC cable for Flow amplifier output;
- 1 × BNC cable for EMG amplifier output 1;
- 1 × BNC cable for EMG amplifier output 2;
- 1 × BNC cable for Pressure transducer/amplifier output;
- spare BNC cable(s);
- manufacturer-specific sensor leads/tubing/electrodes upstream of the amplifier;
- optional known reference/function-generator cable for bench testing.

## EMG cabling

Correct conceptual chain:

```text
Participant
   │
EMG electrodes/sensors
   │
Isolated EMG amplifier / approved wireless receiver
   │  analog output
BNC/appropriate output cable
   │
NI USB-6251 analog input
```

Incorrect:

```text
Participant electrode ───────── NI analog input
```

The recorder does not provide participant electrical isolation.

## Flow cabling and tubing

Flow systems can contain both pneumatic tubing and electrical cables.

```text
Flow head / pneumotach
   │ pneumatic pressure tubing
Differential pressure transducer / flow conditioner
   │ analog voltage output
BNC cable
   │
NI analog input
```

Confirm:

- correct +/− tubing ports;
- no kinks/leaks;
- correct manufacturer zero/calibration procedure;
- known voltage-to-L/s conversion;
- software TARE is used as baseline correction, not a substitute for physical calibration.

## Ground/reference and terminal configuration

The recorder exposes terminal choices including:

- `Default`
- `Differential`
- `SingleEnded`
- `SingleEndedNonReferenced`
- `PseudoDifferential`

The correct mode depends on source grounding and NI channel capabilities.

General guidance:

- determine whether the source is floating or ground-referenced;
- use the NI M-Series manual for measurement configuration;
- avoid creating ground loops between independently powered instruments;
- investigate grounding/isolation before masking noise with software filtering;
- follow the upstream instrument's isolated-output instructions.

## Cable strain relief and labeling

For participant testing:

- route cables away from foot traffic;
- provide strain relief;
- label both ends of each BNC cable (for example `FLOW→AI0`);
- keep a wiring map near the setup;
- document cable changes;
- inspect BNC bayonet locking.

Suggested labeling:

```text
AI0 — FLOW — L/s
AI1 — EMG_DIAPH — mV
AI2 — EMG_SCM — mV
AI3 — PRESSURE — cmH2O
```

Match labels on physical cable, NI input, recorder configuration, and study setup sheet.

## Before connecting an unfamiliar device

Check:

- output signal type;
- voltage range;
- output impedance/required termination;
- grounding/isolation;
- connector pinout;
- excitation requirements;
- bandwidth/filtering;
- compatibility with a general-purpose DAQ.

A BNC connector alone does not guarantee electrical compatibility.

---

Cabling documentation maintained by **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/
