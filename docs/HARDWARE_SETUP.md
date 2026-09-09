# Hardware Prerequisites and Setup

**Project:** NI Multi-Channel Recorder for MATLAB  
**Author/Maintainer:** **Vinay Shankar**  
**Email:** vinay@tfaworld.org  
**Website:** https://tfaworld.org/

This guide focuses on the **NI USB-6251 (BNC)** configuration used to develop the recorder. Other NI-DAQmx devices may work, but connectors, ranges, terminal modes, power requirements, and maximum rates may differ.

## Minimum hardware bill of materials

| Item | Required? | Purpose |
|---|---:|---|
| Windows PC/workstation | Yes | Runs MATLAB, NI-DAQmx, and the recorder |
| NI USB-6251 (BNC) | Yes for this documented setup | Analog acquisition hardware |
| NI-approved/compliant external power supply | Yes for USB-6251 | Powers the DAQ |
| Hi-Speed USB 2.0 Type-A ↔ Type-B cable | Yes | Computer-to-DAQ communication |
| BNC signal cable(s) | Yes for BNC analog sources | Analog source to NI AI input |
| Sensor/transducer/amplifier | Yes | Produces the physical signal/electrical output |
| Signal conditioning / physiological amplifier | Depends on sensor | Amplification, filtering, isolation, excitation, scaling |
| Calibration/reference source | Strongly recommended | Validates polarity, scaling, noise, acquisition |
| Controlled backup/storage | Strongly recommended | Protects irreplaceable data |

## NI USB-6251 BNC characteristics relevant here

NI describes the USB-6251 as an M-Series multifunction I/O device with 16-bit analog input capability. NI specifies up to **1.25 MS/s single-channel** and **1.00 MS/s aggregate for multichannel analog input** for the USB-6251 family.

The BNC version provides front-panel BNC access for analog inputs such as `AI 0` through `AI 7`, with additional analog/digital/timing connectivity.

Do not choose sample rate from the hardware maximum alone. Use signal bandwidth, upstream filtering, number of channels, analysis goals, storage requirements, and protocol.

## DAQ power

The USB-6251 requires external DC power in addition to USB data. NI specifications for USB M-Series 625x devices describe a **11–30 VDC, 20 W** power requirement and state that USB devices should use an NI-offered AC adapter or an appropriately certified NEC Class 2 DC source meeting device requirements.

For normal laboratory use, use the correct NI supply supplied/approved for the hardware unless another source has been institutionally validated. Do not improvise the power connector or polarity.

## Computer connection

NI's 62xx accessory documentation states that USB Multifunction I/O 62xx devices connect to a PC using a **Hi-Speed USB 2.0 cable with USB Type-A and Type-B connectors on opposite ends**.

Recommended practice:

- connect directly to a stable computer USB port when possible;
- avoid an unvalidated low-quality hub;
- use a known-good cable of reasonable length;
- secure USB and power cables during participant testing.

## Analog signal sources

### Flow

A respiratory flow chain may include:

1. flow head/pneumotachograph;
2. differential pressure tubing;
3. pressure transducer or flow conditioner/amplifier;
4. analog voltage output;
5. BNC cable to NI analog input;
6. voltage-to-L/s calibration entered in the recorder.

Follow the flow-system manufacturer's calibration/tubing instructions.

### EMG

Typical surface EMG chain:

1. electrodes/sensors;
2. **isolated physiological/EMG amplifier or approved wireless system**;
3. amplifier analog output;
4. BNC/appropriate output cable;
5. NI analog input.

**Do not connect body electrodes directly to the NI USB-6251.** The DAQ is not a substitute for a medical/physiological isolation amplifier.

### Pressure

Pressure acquisition commonly requires:

1. pressure transducer;
2. required excitation/bridge conditioner/amplifier;
3. calibrated analog voltage output;
4. BNC cable to NI input;
5. correct Scale/Offset in the recorder.

## Input compatibility

Before connecting any source:

- check maximum output voltage;
- check NI input range/working-voltage limits;
- verify grounding/reference behavior;
- never assume a source is safe merely because it has a BNC connector.

## Human-subject electrical safety

For human-subject research:

- use appropriate isolated/approved physiological amplifiers;
- follow institutional electrical-safety policy;
- avoid ground loops through multiple body-connected instruments;
- do not use the MATLAB application as a substitute for hardware isolation;
- do not connect a participant directly to DAQ ground/AI with improvised wiring;
- inspect cables before each session.

## Recommended bench validation

1. Power NI device.
2. Connect USB cable.
3. Confirm detection in NI MAX.
4. Confirm detection in MATLAB with `daqlist("ni")`.
5. Connect one known signal source.
6. Acquire at a conservative rate.
7. Verify polarity and voltage.
8. Apply engineering Scale/Offset.
9. Test TARE where appropriate.
10. Repeat for each input channel.

## Official references

- https://www.ni.com/en/shop/hardware/voltage/model-usb-6251
- https://www.ni.com/en/support/documentation/cable-accessory-guide/daq-multifunction-i-o-cable-accessory-compatibility/main-page---daq-multifunction-i-o-cable-and-accessory-compatibil/62xx-models.html

---

Hardware documentation maintained by **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/
