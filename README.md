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

What is a Language Processing Unit (LPU)?
------------------------------------------
A Language Processing Unit is specialized hardware designed to accelerate neural network workloads for processing text—such as understanding or generating language with large language models. Instead of using a general-purpose CPU (which is slower and energy-hungry for this task), an LPU performs heavy matrix multiplication and data movement operations very efficiently. This allows language models to run faster and with much lower power consumption. The Source of Trust shown here protects the LPU's root cryptographic keys, model integrity, secure boot, and firmware validation—essential for a trustworthy AI accelerator.

Why does an LPU need a Source of Trust?
---------------------------------------
LPUs process valuable data (model weights, user prompts, outputs) and must ensure:
1. **Secure Boot**: Only authenticated firmware runs on the LPU
2. **Model Integrity**: AI models haven't been tampered with
3. **Secure Keys**: Cryptographic keys are protected and accessed only by authorized components
4. **Trusted Startup**: The chain of trust begins at power-on with the SoT

LPU Design Goals represented in this SoT
-----------------------------------------
The Groq LPU whitepaper identifies three core hardware design pillars that enable
real-time inference at scale: low latency, predictable (deterministic) execution,
and energy/cost efficiency. This SoT implementation embodies each of these
principles at the RTL level.

### 1. Low Latency

The Groq architecture eliminates variable-delay memory hierarchies (caches, DRAM
fetches) in favour of fixed-cycle datapaths. This SoT mirrors that philosophy:

| Path                          | Latency  | RTL Module          | Mechanism                                         |
|-------------------------------|----------|---------------------|---------------------------------------------------|
| Access-control decision       | 0 cycles (combinatorial) | `access_control.sv` | Single bitmask lookup (`policy_r[client_id_i]`)   |
| Key ROM read                  | 1 cycle  | `root_key_rom.sv`   | Registered output from combinatorial ROM array    |
| Request → Response (end-to-end) | 2 cycles | `handshake_if.sv` | Two-stage pipeline with no stalls                  |
| MMIO register read            | 1 cycle  | `mmio_if.sv`        | Registered mux output driven next cycle            |

Specifically in the code:
- `access_control.sv` — the `allow_o` output is a pure combinatorial function
  of the policy register and the incoming `client_id_i`, meaning the security
  gate adds zero pipeline bubbles to the data path.
- `root_key_rom.sv` — uses a simple array (`mem[]`) read combinatorially and
  then registered in a single `always_ff` stage, guaranteeing exactly one clock
  cycle from index presentation to key output.
- `handshake_if.sv` — implements a strict two-stage pipeline (`req_pending_1` →
  `req_pending_2` → `resp_v_o`) with no conditional retry or backpressure stalls.

This is directly analogous to the Groq TSP's deterministic instruction scheduling,
where every operation's completion time is known at compile/design time.

### 2. Predictable Execution

The Groq whitepaper emphasises that LPU hardware must behave identically on
every invocation—no cache misses, no speculative execution, no variable-latency
memory. The SoT achieves this through:

- **No caches or DRAM** — `root_key_rom.sv` stores keys in a fixed SRAM/ROM
  array with constant access time. There is no cache hierarchy that could
  introduce timing variability.
- **No complex state machines** — `handshake_if.sv` uses a linear two-stage
  pipeline. Progression through stages is unconditional once a valid request
  is accepted; there are no retry loops or variable-depth queues.
- **Fully registered outputs** — every module (`access_control.sv`,
  `root_key_rom.sv`, `mmio_if.sv`, `handshake_if.sv`) drives its outputs from
  `always_ff` blocks, ensuring outputs transition only on clock edges and
  downstream timing analysis is straightforward.
- **Decoupled planes** — management (MMIO) and data (key request) traffic are
  structurally independent in `lpu_sot_top.sv`, so policy updates cannot stall
  or delay key reads.
- **Simulation assertions** — `root_key_rom.sv` and `access_control.sv` include
  `$warning` checks that fire if unexpected conditions occur, enabling early
  detection of timing/protocol violations during verification.

These properties mean a bootloader or firmware can schedule key retrieval and
know, with hardware-guaranteed certainty, exactly when the response will arrive.

### 3. Energy / Cost Efficiency

The Groq architecture achieves high throughput-per-watt by eliminating
unnecessary hardware complexity. The SoT follows suit:

- **Minimal gate count** — `access_control.sv` is a single register plus a
  one-hot bit select. No comparators, no priority encoders, no TLB-style
  translation.
- **Single-port ROM** — `root_key_rom.sv` uses one read port (no multi-port
  SRAM or tag arrays), minimising area and leakage.
- **No clock-domain crossings** — the entire design is single-clock,
  eliminating synchroniser flops, gray-code FIFOs, and associated power.
- **Async-assert / sync-deassert reset** — all `always_ff` blocks use
  `negedge rst_ni` for immediate power-on reset without requiring a separate
  reset clock, saving routing and area.
- **Implicit clock gating potential** — because `mmio_if.sv` and the data
  plane are structurally decoupled, synthesis tools can gate the management
  plane clock when idle without affecting data-plane throughput.
- **Parameterisation over duplication** — widths (`KEY_WIDTH`, `ID_WIDTH`,
  `KEY_DEPTH`) are parameters, allowing a single RTL source to be synthesised
  at exactly the size required for a given product SKU rather than
  over-provisioning hardware.

The net result is a security IP block that occupies a fraction of the area of
a traditional key-management engine while still meeting the timing guarantees
required by LPU secure boot.

This implementation provides:

- A read-only ROM storing root keys
- A small access-control unit which permits or denies requests based on a simple policy register
- A handshake interface where a client requests a key and the SoT responds when allowed

Design notes and best practices
-------------------------------
This implementation is intentionally small and suitable as a starting reference. The following practices were followed and are recommended when integrating into silicon:

- Parameterize widths (key width, ID width, depth) and avoid magic numbers
- Use synchronous logic for registers and clear reset semantics (async assert / sync de-assert as in many OpenTitan modules)
- Add assertions for protocol correctness and keep error paths explicit
- Keep one module per file and use named port connections for readability
- Decouple management (MMIO) and data (key request) planes to avoid timing interference
- Document latency guarantees and pipeline depth in comments

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

