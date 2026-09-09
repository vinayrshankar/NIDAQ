# Installation and Software Prerequisites

**Project:** NI Multi-Channel Recorder for MATLAB  
**Author/Maintainer:** **Vinay Shankar**  
**Email:** vinay@tfaworld.org  
**Website:** https://tfaworld.org/  
**Repository:** https://github.com/vinayrshankar/NIDAQ

## Required software

### MATLAB

The recorder requires MATLAB with programmatic `uifigure`/`uiaxes` support and the modern Data Acquisition interface. The development environment used MATLAB **R2024a**. Other releases may work, but validate NI driver/support-package compatibility before research use.

### Data Acquisition Toolbox

Install **Data Acquisition Toolbox**. The recorder uses `daq`, `daqlist`, `daqvendorlist`, `daqreset`, `addinput`, `start`, `stop`, `read`, and `ScansAvailableFcn`.

### Data Acquisition Toolbox Support Package for National Instruments NI-DAQmx Devices

MATLAB requires the NI support package/adaptor to communicate with NI-DAQmx hardware.

1. Open MATLAB **Home**.
2. Select **Add-Ons**.
3. Select **Get Hardware Support Packages**.
4. Install the National Instruments NI-DAQmx support package appropriate for the MATLAB release.
5. Reboot after installation if device discovery does not work.

### NI-DAQmx

NI-DAQmx must be installed and operational. The development acquisition computer reported:

```text
MATLAB adaptor: 24.1 (R2024a)
NI-DAQmx:        23.8.0
```

This is the observed project environment, not a universal requirement. Use MathWorks' NI-DAQmx compatibility information for the MATLAB release being deployed.

### NI Measurement & Automation Explorer (NI MAX)

NI MAX is strongly recommended for device detection, hardware self-test, device naming, and troubleshooting.

## Confirm MATLAB sees NI support

Run:

```matlab
daqvendorlist
```

A working installation should include vendor ID `ni`.

Then run:

```matlab
daqlist("ni")
```

On the development system, the NI USB-6251 BNC appeared as `dev2`. Device IDs are machine-specific.

## If the device does not appear

Try:

```matlab
daqreset
daqlist("ni")
```

Then verify:

1. DAQ external power.
2. USB connection.
3. Device visibility in NI MAX.
4. NI-DAQmx installation.
5. MATLAB NI support package installation.
6. `daqvendorlist` status.
7. Another known-good USB Type-A↔Type-B cable/port if needed.

## Install and launch the recorder

Clone/download:

```text
https://github.com/vinayrshankar/NIDAQ
```

Make the repository the MATLAB Current Folder or add it to the MATLAB path.

Run:

```matlab
NI_MultiChannel_Recorder_v4_03
```

If MATLAB is executing a duplicate copy:

```matlab
which NI_MultiChannel_Recorder_v4_03 -all
```

## Recommended software-validation sequence

Before participant/sensor acquisition:

```matlab
daqvendorlist
daqlist("ni")
```

Then:

1. Confirm the expected device ID.
2. Enable one known input.
3. Use a conservative test rate such as 1,000 or 5,000 Hz.
4. Start acquisition.
5. Confirm its independent signal window updates.
6. Stop and save a test file.
7. Confirm row count and timestamp column.

## Official references

- https://www.mathworks.com/help/daq/
- https://www.mathworks.com/help/daq/hardware-discovery-and-setup.html
- https://www.mathworks.com/hardware-support/nidaqmx.html
- https://www.mathworks.com/help/daq/install-hardware-support-package-for-vendor-support.html

---

Documentation maintained by **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/
