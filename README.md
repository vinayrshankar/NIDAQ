# NI Multi-Channel Recorder for MATLAB

A configurable MATLAB data-acquisition application for National Instruments NI-DAQmx hardware, with **one independent live signal window per enabled analog input channel**, persistent channel configurations, UTC millisecond timestamps, and a session-specific **Baseline / TARE** workflow.

**Current version:** 4.0.3  
**Author and maintainer:** **Vinay Shankar**  
**Email:** [vinay@tfaworld.org](mailto:vinay@tfaworld.org)  
**Website:** <https://tfaworld.org/>  
**GitHub:** <https://github.com/vinayrshankar/NIDAQ>  
**License:** GNU General Public License v2.0 (GPL-2.0)

> This recorder and its documentation are authored and maintained by **Vinay Shankar**. Please preserve the author/contact information when redistributing or modifying the project under the terms of GPL-2.0.

## What version 4.0.3 adds

Version 4.0.3 builds on the independent-window V4 architecture and adds a dedicated **Baseline / TARE** screen.

- The control/configuration window contains no signal axes.
- Every enabled channel opens in its own independent `uifigure`.
- Each signal window contains exactly one `uiaxes` and one plot line.
- Channels can have independent labels, units, calibration scale/offset, terminal configuration, Auto-Y state, and manual Y limits.
- Channel configurations can be saved, loaded, and automatically restored.
- MATLAB stores only one exported time column: `SampleStartUTC_ms`.
- TARE uses the mean of a recent baseline window rather than a single instantaneous sample.
- TARE is kept separate from calibration and is session-specific.
- MAT-file metadata records calibration parameters, TARE parameters, version, author, contact information, and project repository.

## Main program

Run:

```matlab
NI_MultiChannel_Recorder_v4_03
```

Source file:

```text
NI_MultiChannel_Recorder_v4_03.m
```

The previous `NI_MultiChannel_Recorder_v4_02.m` is retained for version history. New work should use V4.0.3 unless an older workflow must be reproduced.

## Documentation

- **[Installation and software prerequisites](docs/INSTALLATION.md)**
- **[Hardware prerequisites and bill of materials](docs/HARDWARE_SETUP.md)**
- **[Cabling, BNC connections, grounding, and signal-chain guidance](docs/CABLING_AND_WIRING.md)**
- **[Baseline / TARE workflow](docs/BASELINE_TARE.md)**
- **[Troubleshooting and diagnostics](docs/TROUBLESHOOTING.md)**
- **[Example channel configurations](docs/EXAMPLE_CONFIGURATIONS.md)**
- **[Authors and project attribution](AUTHORS.md)**
- **[Version history](CHANGELOG.md)**

## Tested development context

The recorder was developed around this acquisition environment:

- National Instruments **USB-6251 (BNC)**
- MATLAB **R2024a**
- MATLAB Data Acquisition Toolbox
- National Instruments NI-DAQmx support through MATLAB
- NI-DAQmx **23.8.0** observed on the development acquisition computer
- Device ID observed as `dev2` on that computer

Device IDs are machine-specific. Never assume another computer will call the device `dev2`; use:

```matlab
daqvendorlist
daqlist("ni")
```

The `ni` vendor should be operational and the expected DAQ should appear in `daqlist("ni")` before research acquisition.

## Hardware summary

For the NI USB-6251 BNC workflow, the typical minimum physical setup is:

1. Windows workstation/laptop with MATLAB and a usable USB host port.
2. NI USB-6251 BNC DAQ.
3. Correct NI power supply or compliant external DC supply for the USB-6251.
4. Hi-Speed USB 2.0 **Type-A to Type-B** cable between the computer and DAQ.
5. One appropriate **BNC signal cable per analog source** being acquired.
6. Sensor/transducer/amplifier hardware that produces an analog voltage compatible with the NI input.
7. Appropriate isolation/signal conditioning for any human-connected physiological instrumentation.

See [Hardware Setup](docs/HARDWARE_SETUP.md) and [Cabling and Wiring](docs/CABLING_AND_WIRING.md) before connecting signals.

## Important physiological-signal safety note

This is a **general-purpose research DAQ application**, not a medical device. Do not connect human-subject electrodes or other body-connected conductors directly to a general-purpose NI analog input. EMG and similar physiological signals should reach the NI device through an appropriate isolated/approved amplifier and signal-conditioning chain, with institutional electrical-safety procedures followed.

The software does not create electrical isolation.

## Acquisition architecture

The recorder uses MATLAB's modern Data Acquisition interface:

```matlab
dq = daq("ni");
addinput(...);
dq.ScansAvailableFcn = ...;
start(dq,"continuous");
read(...,OutputFormat="Matrix");
```

Engineering conversion:

```text
calibratedValue = rawVoltage × Scale + CalibrationOffset
finalValue      = calibratedValue + TareOffset
```

TARE therefore does **not** rewrite hardware/sensor calibration.

## Baseline / TARE workflow

A typical acquisition is:

1. Configure and verify channels.
2. Press **START**.
3. Establish a quiet/stable baseline condition.
4. Open **BASELINE / TARE**.
5. Choose a baseline duration (default 1 s).
6. Select the channels to zero.
7. Press **TARE SELECTED**.
8. Verify that the displayed baseline is approximately zero.
9. Continue the experimental task.
10. Press **STOP** and save.

If a channel has a pre-TARE baseline mean of `+0.437 L/s`, the recorder applies approximately `-0.437 L/s` as that channel's TARE correction.

See [Baseline / TARE](docs/BASELINE_TARE.md) for details.

## Timing

The saved timing column is:

```text
SampleStartUTC_ms
```

Elapsed time is used internally to draw live plots but is not exported as a second time variable. The timestamp is derived from the acquisition trigger time plus MATLAB/NI relative scan timestamps.

For experiments requiring strict synchronization with another independent acquisition system, externally validate timing and hardware latency. Software-generated absolute timestamps should not automatically be treated as physical event-onset timestamps with sub-millisecond accuracy.

## Data output

### CSV

CSV contains:

```text
SampleStartUTC_ms,Channel_1,Channel_2,...
```

Channel columns contain the final engineering signal after calibration and any active session TARE.

### MAT

MAT output includes:

- `sampleStartUTCms`
- `rawData`
- `scaledData`
- `metadata`

Metadata includes project/version provenance plus calibration and TARE information so the processing chain can be reconstructed.

## Configuration behavior

V4.0.3 stores its automatic persistent configuration separately in the MATLAB preference directory:

```text
NI_MultiChannel_Recorder_v4_03_lastconfig.mat
```

Reusable configuration includes channel setup and the preferred baseline duration. **Measured TARE offsets are intentionally not persisted between sessions.** A new acquisition session should establish a new baseline when required.

## Sampling-rate note

The NI USB-6251 family is a 16-bit M-Series multifunction DAQ. NI specifies up to 1.25 MS/s for a single analog-input channel and 1.00 MS/s aggregate for multichannel acquisition. Practical research sampling rates should be chosen from signal bandwidth, upstream filters/amplifiers, number of channels, storage needs, and experimental protocol rather than simply using the hardware maximum.

## Recommended validation before real data collection

Before using the recorder for irreplaceable participant data:

1. Verify each physical cable maps to the expected MATLAB channel.
2. Verify units and engineering Scale/Offset against the upstream device.
3. Record a known reference/test signal.
4. Confirm polarity.
5. Confirm TARE produces the expected zero baseline.
6. Confirm expected sampling rate in the GUI.
7. Save a short test CSV and MAT file and reopen them.
8. Confirm timestamps and row counts.
9. Confirm independent plot windows update without dropped acquisition.
10. Document the final hardware configuration used in the study.

## Official references

- MathWorks Data Acquisition Toolbox: <https://www.mathworks.com/help/daq/>
- MathWorks NI-DAQmx support: <https://www.mathworks.com/hardware-support/nidaqmx.html>
- NI USB-6251 product page and manuals/specifications: <https://www.ni.com/en/shop/hardware/voltage/model-usb-6251>
- NI 62xx cable/accessory compatibility: <https://www.ni.com/en/support/documentation/cable-accessory-guide/daq-multifunction-i-o-cable-accessory-compatibility/main-page---daq-multifunction-i-o-cable-and-accessory-compatibil/62xx-models.html>

## Project structure

```text
NIDAQ/
├── NI_MultiChannel_Recorder_v4_03.m
├── NI_MultiChannel_Recorder_v4_02.m
├── README.md
├── AUTHORS.md
├── CHANGELOG.md
├── CITATION.cff
├── LICENSE
└── docs/
    ├── INSTALLATION.md
    ├── HARDWARE_SETUP.md
    ├── CABLING_AND_WIRING.md
    ├── BASELINE_TARE.md
    ├── TROUBLESHOOTING.md
    └── EXAMPLE_CONFIGURATIONS.md
```

## Author

**Vinay Shankar**  
Email: [vinay@tfaworld.org](mailto:vinay@tfaworld.org)  
Website: <https://tfaworld.org/>  
GitHub: <https://github.com/vinayrshankar/NIDAQ>

This recorder, V4 architecture, Baseline/TARE implementation, and project documentation are maintained by **Vinay Shankar**.

## License

This project is distributed under the **GNU General Public License, Version 2**. See [LICENSE](LICENSE).
