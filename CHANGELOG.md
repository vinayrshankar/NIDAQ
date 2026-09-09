# Changelog

Project author/maintainer: **Vinay Shankar** — vinay@tfaworld.org — https://tfaworld.org/

## 4.0.3 — Baseline / TARE

- Added Baseline / TARE screen.
- Added per-channel TARE selection.
- Added configurable recent baseline duration.
- TARE uses mean recent calibrated baseline rather than a single sample.
- Separated `TareOffset` from calibration `Scale` and `CalibrationOffset`.
- Added clear-TARE behavior.
- Added TARE information to independent live signal windows.
- Added TARE/calibration provenance to MAT metadata.
- Kept TARE session-specific rather than persisting as reusable hardware calibration.
- Added extensive author/contact attribution in source and metadata.
- Added comprehensive installation, hardware, cabling, baseline, troubleshooting, and example-configuration documentation.

## 4.0.2 — Callback-count correction

- Allowed MATLAB to use its valid default `ScansAvailableFcnCount` rather than forcing the minimum callback boundary.
- Preserved all acquired samples while improving acquisition robustness.

## 4.0.1 — Syntax and independent-window cleanup

- Corrected MATLAB string syntax issue.
- Used a unique version/function name to avoid accidental cached older files.

## 4.0 — Independent signal windows

- Introduced standalone V4 architecture.
- Control window contains no signal axes.
- Every enabled channel opens in an independent MATLAB figure/window.
- Added independent Y-axis handling and persistent channel configuration.
