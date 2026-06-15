// access_control.sv
// Access Control Unit for LPU Source of Trust (SoT)
//
// LPU Architecture Mapping:
// - LOW LATENCY: Zero-cycle combinatorial decision (no pipeline bubbles on data path).
//   The policy lookup is a single bit-select from a register, meaning the access
//   gate adds no additional clock cycles to the key retrieval path.
// - PREDICTABLE EXECUTION: The allow_o output is purely combinatorial with no
//   state-dependent timing variation. Every request is resolved identically
//   regardless of history — no priority arbitration, no queuing, no speculation.
// - ENERGY/COST EFFICIENCY: One register (POLICY_WIDTH bits) and one mux. No
//   comparators, CAMs, or multi-level permission tables. Minimal switching
//   activity: policy_r only toggles on explicit MMIO writes.
//
// References: Groq LPU whitepaper — deterministic instruction scheduling and
// fixed-function execution units with compile-time-known latencies.

module access_control #(
    parameter int ID_WIDTH = 2,                       // Number of client ID bits
    parameter int POLICY_WIDTH = (1 << ID_WIDTH)      // Policy register width (auto-calculated)
) (
    input  logic                        clk,
    input  logic                        rst_ni,       // Active-low async reset (assert), sync de-assert

    // Request signals (data plane, low latency path)
    input  logic [ID_WIDTH-1:0]         client_id_i,  // Which client is requesting
    input  logic [1:0]                  op_i,         // Operation: 0=read (write/other ops denied)

    // Policy programming interface (management plane, decoupled from data path)
    input  logic                        policy_wr_v_i,           // Write enable for policy register
    input  logic [POLICY_WIDTH-1:0]     policy_wr_data_i,        // New policy value

    // Decision output (feeds directly into key ROM and handshake gating)
    output logic                        allow_o                  // 1=access allowed, 0=denied
);

    // Single policy register: bit[i] = 1 means client i can read keys
    logic [POLICY_WIDTH-1:0] policy_r;

    // Pipeline stage for deterministic latency: decision is combinatorial
    logic allow_comb;

    // ========================================================================
    // POLICY REGISTER UPDATE
    // Management plane: decoupled from request processing
    // ========================================================================
    // Inline the mux logic to avoid potential issues with intermediate signals

    // ========================================================================
    // ACCESS DECISION LOGIC (Combinatorial — zero added latency)
    // LOW LATENCY: No registered output stage; decision available same cycle.
    // PREDICTABLE: Identical timing for allow and deny paths (no early-exit).
    // Only read operations (op==0) are permitted in this reference SoT.
    // ========================================================================
    assign allow_comb = (op_i == 2'b00) ? policy_r[client_id_i] : 1'b0;

    // ========================================================================
    // SYNCHRONOUS REGISTER UPDATE
    // ENERGY EFFICIENCY: policy_r only updates when policy_wr_v_i is asserted,
    // preventing unnecessary toggle activity on the register.
    // Async assert / sync de-assert reset ensures immediate safe state on power-on.
    // ========================================================================
    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            policy_r <= '0;              // All clients denied on reset
        end else begin
            // Inline ternary: update policy if write is valid, otherwise hold
            if (policy_wr_v_i) begin
                policy_r <= policy_wr_data_i;
            end else begin
                policy_r <= policy_r;  // Hold current value
            end
        end
    end

    // Output decision: combinatorial (no pipeline delay) for fast access
    assign allow_o = allow_comb;

    // ========================================================================
    // ASSERTIONS (Simulation only)
    // Verify correct policy width and catch configuration errors early
    // ========================================================================
    `ifndef SYNTHESIS
    initial begin
        if (POLICY_WIDTH != (1 << ID_WIDTH)) begin
            $warning("access_control: POLICY_WIDTH (%0d) != 2^ID_WIDTH (2^%0d)",
                     POLICY_WIDTH, ID_WIDTH);
        end
    end

    // Assert that client ID never exceeds policy width
    always_ff @(posedge clk) begin
        if (client_id_i >= POLICY_WIDTH) begin
            $warning("access_control: client_id_i (%0d) exceeds POLICY_WIDTH (%0d)",
                     client_id_i, POLICY_WIDTH);
        end
    end
    `endif

endmodule

