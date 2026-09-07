# NI Multi-Channel Recorder for MATLAB

A configurable MATLAB acquisition GUI for recording multiple analog channels from National Instruments DAQ hardware while displaying **each enabled channel in its own independent live plot window**.

**Current version:** 4.0.2  
**Author:** Vinay Shankar  
**Website:** https://tfaworld.org/  
**Email:** vinay@tfaworld.org  
**License:** GPL-2.0

## Overview

This project was built for laboratory data-acquisition workflows that need a simple MATLAB interface for configuring, monitoring, and saving multiple NI-DAQ input channels without overlaying signals on a shared plot.

Version 4 uses an intentionally independent-window architecture:

- the control/configuration window contains no signal axes;
- every enabled channel opens in its own `uifigure`;
- each signal window contains exactly one `uiaxes` and one plot line;
- each channel has independent label, unit, scaling, offset, terminal configuration, and Y-axis settings;
- acquisition settings can be saved and restored;
- recorded data are saved with a UTC millisecond time column.

## Main program

Run:

```matlab
NI_MultiChannel_Recorder_v4_02
```

The current source file is:

```text
NI_MultiChannel_Recorder_v4_02.m
```

Older README material referring to `v4_01` is retained only as a historical text file and should not be used as the launch instruction for the current version.

## Requirements

### Required

- MATLAB with `uifigure` support
- MATLAB Data Acquisition Toolbox
- National Instruments NI-DAQmx driver
- a MATLAB-supported National Instruments DAQ device
- Windows is recommended for NI-DAQmx laboratory deployments

### Tested development context

The software was developed around an **NI USB-6251 (BNC)** workflow. Device IDs such as `dev2` are machine-specific; always use the ID returned by MATLAB on the acquisition computer.

Check available NI hardware with:

```matlab
daqlist("ni")
```

## Acquisition architecture

The program uses MATLAB's modern Data Acquisition interface:

```matlab
dq = daq("ni");
addinput(...);
dq.ScansAvailableFcn = ...;
start(dq,"continuous");
read(...,OutputFormat="Matrix");
```

Each configured channel can define:

- device ID;
- physical channel ID;
- descriptive label;
- engineering unit;
- scale;
- offset;
- terminal configuration;
- automatic or manual Y-axis limits.

Engineering conversion follows:

```text
engineeringValue = rawVoltage × Scale + Offset
```

## Quick start

1. Install MATLAB, Data Acquisition Toolbox, and NI-DAQmx.
2. Connect and verify the NI device in NI MAX or the applicable NI configuration utility.
3. In MATLAB, confirm the device appears with `daqlist("ni")`.
4. Clone or download this repository.
5. Make the repository the current MATLAB folder or add it to the MATLAB path.
6. Run:

```matlab
NI_MultiChannel_Recorder_v4_02
```

7. Confirm the default device or enter the correct device ID.
8. Set the sample rate.
9. Configure each enabled channel.
10. Start acquisition and confirm each signal appears in its own window.
11. Stop acquisition and save the recording using the GUI controls.

## Timing

The saved timing column is:

```text
SampleStartUTC_ms
```

Elapsed time is used internally for visualization but is not saved as a second time column. This keeps exported recordings tied to a single UTC-based time reference.

For experiments requiring precise synchronization with external systems, independently validate timing and hardware latency. Software timestamps alone should not be assumed to represent exact physical event onset.

## Configuration

Version 4.0.2 uses its own persistent configuration file in the MATLAB preferences directory:

```text
NI_MultiChannel_Recorder_v4_02_lastconfig.mat
```

This prevents configuration state from earlier recorder versions from being silently reused.

## Data-safety recommendations

- Verify channel labels and physical terminals before every acquisition session.
- Run a short test recording before participant data collection.
- Confirm scaling and units against the connected sensor/amplifier.
- Save data to a controlled research location with routine backups.
- Do not rely on the GUI as the sole copy of irreplaceable recordings.
- Validate the complete acquisition chain before using the system in a study protocol.

## Project files

```text
NIDAQ/
├── NI_MultiChannel_Recorder_v4_02.m
├── NI_MultiChannel_Recorder_v4_01_README (1).txt
├── README.md
└── LICENSE
```

## Research software notice

This repository provides general-purpose research acquisition software. It is not a medical device and is not intended for diagnosis, treatment, or clinical decision-making.

National Instruments, NI, NI-DAQmx, and related product names are trademarks of their respective owners. This project is independently developed and is not an official National Instruments product.

## Author

**Vinay Shankar**  
Website: https://tfaworld.org/  
Email: vinay@tfaworld.org

## License

This project is distributed under the **GNU General Public License, Version 2**. See [LICENSE](LICENSE).
