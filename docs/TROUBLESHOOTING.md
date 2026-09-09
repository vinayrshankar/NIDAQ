# Troubleshooting

**Author/Maintainer:** **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/

## NI device not detected

Run:

```matlab
daqvendorlist
daqreset
daqlist("ni")
```

If `daqvendorlist` does not show NI, install/repair the MATLAB NI-DAQmx support package and NI-DAQmx.

If NI appears but `daqlist("ni")` is empty:

- confirm external DAQ power;
- check USB Type-A↔Type-B cable;
- confirm the DAQ appears in NI MAX;
- try `daqreset`;
- reboot after driver installation;
- try another known-good USB port/cable.

## Correct device but START fails

Check:

- exact DeviceID from `daqlist("ni")`;
- physical channel ID (`ai0`, `ai1`, etc.);
- terminal configuration;
- sample rate;
- enabled channel count;
- whether another program reserves the NI device.

## "At the specified rate, the minimum count allowed is ..."

V4.0.2+ leaves `ScansAvailableFcnCount` at MATLAB's valid default instead of forcing the minimum callback boundary. If the error appears in an older file, confirm V4.0.3:

```matlab
which NI_MultiChannel_Recorder_v4_03 -all
```

## Signal is flat

Check source power/output, BNC lock, correct AI channel, Y-axis limits, source voltage, and Scale value.

## Signal is saturated/clipped

Possible causes include excessive source voltage, excessive amplifier gain, wrong reference configuration, or incorrect engineering scaling. Stop acquisition and verify hardware before continuing.

## Excessive 50/60 Hz noise

Investigate hardware first:

- grounding/reference configuration;
- ground loops;
- amplifier isolation;
- loose shield/BNC cable;
- cable routing near mains/power supplies;
- electrode/contact quality for EMG.

Do not use software filtering merely to hide unsafe/incorrect wiring.

## TARE does not reach exactly zero

TARE zeroes the **mean of a recent window**. The instantaneous signal will still fluctuate around zero.

If the baseline table is not approximately zero:

- ensure acquisition is running;
- ensure enough recent samples exist;
- ensure signal was stable during the window;
- verify correct TARE selection.

## TARE is wrong after moving/reconnecting a sensor

Clear TARE and establish a new baseline. TARE should be repeated whenever the physical zero reference changes.

## MATLAB runs the wrong file

```matlab
which NI_MultiChannel_Recorder_v4_03 -all
clear NI_MultiChannel_Recorder_v4_03
clear functions
rehash
NI_MultiChannel_Recorder_v4_03
```

## Data saving

If save fails, check folder permissions, disk space, local vs network path reliability, and test CSV/MAT separately.

## Bug-report checklist

Include:

- recorder version;
- MATLAB release;
- `daqvendorlist` output;
- `daqlist("ni")` output;
- NI model;
- sample rate;
- enabled channel count;
- exact error and line number;
- stage: launch/START/TARE/STOP/SAVE.

Project contact: **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/
