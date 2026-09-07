NI Multi-Channel Recorder V4.0.1 - Independent Windows

IMPORTANT
---------
Run this exact function:
    NI_MultiChannel_Recorder_v4_01

This unique filename avoids MATLAB accidentally using an older cached V4 file.

Fix in 4.0.1
------------
The previous V4 file had an invalid MATLAB string at the NI discovery message:
    daqlist(\"ni\")
MATLAB does not use backslash escaping inside string scalars. It is corrected to:
    daqlist(""ni"")

Architecture
------------
- Control/configuration window has NO signal axes.
- Every enabled channel opens in its own independent uifigure.
- Each signal window has exactly one uiaxes and one plot line.
- No overlay/combined graph path exists.
- Per-channel Label, Unit, Scale, Offset, Terminal, Auto Y, Y Min and Y Max.
- Only SampleStartUTC_ms is saved as the time column.
- V4.0.1 uses its own persistent configuration:
    NI_MultiChannel_Recorder_v4_01_lastconfig.mat

Recommended launch
------------------
    clear NI_MultiChannel_Recorder_v4_01
    clear functions
    rehash
    NI_MultiChannel_Recorder_v4_01

NI device on the tested system
------------------------------
MATLAB previously reported the NI USB-6251 (BNC) as DeviceID: dev2.
Use the DeviceID returned by daqlist("ni") on the acquisition computer.
