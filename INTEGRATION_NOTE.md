Integration notes: Open-LPU Source of Trust
==========================================

Purpose
-------
This document gives short, pragmatic guidance for integrating the reference LPU Source-of-Trust (SoT) into a larger SoC such as OpenTitan.

Key integration points
----------------------
- RTL placement: move `rtl/` sources into the convention used by the SoC (e.g. `hw/ip/open_lpu/rtl/` for OpenTitan). Keep one file/module per source file.
- Bus/CSR integration: replace the simple `mmio` shim with OpenTitan's register generator and bus adapters (TL-UL / APB / tilelink) following patterns in `opentitan/hw/ip/*/`.
- Reset & clocks: follow project conventions for reset polarity and synchronization. OpenTitan uses `rst_ni` naming in many modules — keep consistent.
- DIF/DV: implement a DIF wrapper in `sw/device` and a minimal DV smoke test in `hw/dv/smoke` to exercise allowed/denied flows.

Security considerations
-----------------------
- ROM vs. OTP: this reference uses a ROM with default keys. For production, consider provisioning via one-time-programmable (OTP) fuses or secure provisioning flow.
- Side channels: this reference is functional not hardened. Cryptographic hardware, side-channel protections, and fault injection mitigations are out of scope and must be added for production.

Files to touch in OpenTitan (suggested)
--------------------------------------
- Add RTL under `hw/ip/open_lpu/rtl/`
- Add `hw/ip/open_lpu/BUILD.bazel` and `hw/ip/BUILD` entries following other IP examples
- Add SCSS/CIF wrappers in `hw/top_*` to expose mmio to the software bus
- Port the mmio registers to the OpenTitan register generator and add DIF/driver

References
----------
- OpenTitan source tree (for coding conventions, register generator, bus adapters): https://github.com/lowRISC/opentitan

