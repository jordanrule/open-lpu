Open LPU - Source of Trust (SoT)
================================

Overview
--------
This repository contains a compact, well-documented SystemVerilog reference implementation of a Language Processing Unit (LPU) Source of Trust (SoT). The design follows the concepts described in the Groq LPU whitepaper (https://arxiv.org/html/2408.07326v1) and uses coding and integration best-practices derived from the lowRISC OpenTitan project (https://github.com/lowRISC/opentitan).

What is included
-----------------
- `rtl/` : SystemVerilog RTL modules (top-level glue, root key ROM, access-control, handshake/messaging wrapper, simple mmio shim)
- `tb/`  : A small self-checking testbench that exercises allowed/denied key reads and handshake behavior
- `INTEGRATION_NOTE.md` : Notes for integrating this SoT into a larger SoC (for example OpenTitan)
- `LICENSE` : Apache License 2.0

Layman explanation
-------------------
Think of the Source of Trust as a tiny vault inside a chip that holds immutable secrets (root keys) and decides who may access those secrets. On power-up the SoT provides the initial secrets needed to validate firmware and to bootstrap secure subsystems.

What is an LPU (Language Processing Unit)?
- A Language Processing Unit is hardware designed to accelerate neural network workloads for text—such as understanding or generating language with large models. It performs the heavy matrix-multiply and data-movement operations efficiently so software can run language models faster and with lower energy than on a general-purpose CPU. The SoT shown here would be used to protect keys, model integrity checks, and secure boot steps for such an LPU.

This implementation provides:

- A read-only ROM storing root keys
- A small access-control unit which permits or denies requests based on a simple policy register
- A handshake interface where a client requests a key and the SoT responds when allowed

Design notes and best practices
------------------------------
This implementation is intentionally small and suitable as a starting reference. The following practices were followed and are recommended when integrating into silicon:

- Parameterize widths (key width, ID width, depth) and avoid magic numbers
- Use synchronous logic for registers and clear reset semantics (async assert / sync de-assert as in many OpenTitan modules)
- Add assertions for protocol correctness and keep error paths explicit
- Keep one module per file and use named port connections for readability

References
----------
- Groq LPU whitepaper: https://arxiv.org/html/2408.07326v1
- OpenTitan (source of integration best practices): https://github.com/lowRISC/opentitan

Simulation
----------
Install Icarus Verilog (macOS):

```bash
brew install icarus-verilog
```

Build and run the small self-checking testbench:

```bash
mkdir -p build
iverilog -g2012 -o build/lpu_sot.vvp open-lpu/rtl/*.sv open-lpu/tb/*.sv
vvp build/lpu_sot.vvp
# Optional: view waveform
# gtkwave build/lpu_sot.vcd
```

License
-------
This work is licensed under the Apache License, Version 2.0. See `LICENSE` for details.

Acknowledgements
----------------
Best practices used to shape this implementation were derived from the OpenTitan project: https://github.com/lowRISC/opentitan

