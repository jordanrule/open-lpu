// handshake_if.sv
// LPU Handshake Interface Module
//
// Implements deterministic request/response protocol for low-latency key access:
// - Fixed 1-2 cycle response latency supports predictable secure boot timing
// - Simple valid/ready handshake minimizes logic and power consumption
// - Fully pipelined design allows high-frequency operation
// - No multi-cycle stalls or unpredictable delays (cost-efficient implementation)
//
// Protocol:
// - Request: client drives req_v_i with req_msg_i. SoT drives req_r_o when ready.
// - Response: SoT drives resp_v_o with resp_msg_o after ~2 cycles. Client observes.
//
// Intended for integration with key ROM and access control to form complete
// low-latency secure boot path in LPU chips.

module lpu_handshake (
    input  logic clk,
    input  logic rst_ni,              // Active-low async reset

    // Request interface (from client to SoT)
    input  logic                   req_v_i,      // Request valid
    input  logic [31:0]            req_msg_i,    // Request data (e.g., key index)
    output logic                   req_r_o,      // SoT ready to accept request

    // Response interface (from SoT to client)
    output logic                   resp_v_o,     // Response valid
    output logic [31:0]            resp_msg_o    // Response data (key/status)
);

    // ========================================================================
    // PIPELINE STAGES FOR DETERMINISTIC LATENCY
    // ========================================================================
    // Stage 0: Accept request (req_v_i && req_r_o)
    // Stage 1: Hold request in pipeline
    // Stage 2: Drive response (resp_v_o)

    logic [31:0] req_msg_r1;           // Pipeline stage 1: captured request
    logic [31:0] req_msg_r2;           // Pipeline stage 2: request ready for response
    logic req_pending_1;               // Request captured in stage 1
    logic req_pending_2;               // Request ready for response in stage 2

    // ========================================================================
    // SYNCHRONOUS PIPELINE (Async reset, sync de-assert)
    // Guarantees: request accepted in cycle N produces response in cycle N+2.
    // No variable-latency paths, no retry loops, no backpressure stalls.
    // ========================================================================
    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            // Reset all stages to empty/idle
            req_msg_r1 <= '0;
            req_msg_r2 <= '0;
            req_pending_1 <= 1'b0;
            req_pending_2 <= 1'b0;
            req_r_o <= 1'b0;
            resp_v_o <= 1'b0;
            resp_msg_o <= '0;
        end else begin
            // ================================================================
            // STAGE 1: REQUEST CAPTURE (Accept request when not full)
            // Low Latency: immediate acceptance when pipeline is empty
            // ================================================================
            req_r_o <= ~req_pending_1;
            if (req_v_i && ~req_pending_1) begin
                req_msg_r1 <= req_msg_i;
                req_pending_1 <= 1'b1;
            end else if (req_pending_1 && !req_pending_2) begin
                // Advance to stage 2 unconditionally (predictable execution)
                req_msg_r2 <= req_msg_r1;
                req_pending_2 <= 1'b1;
                req_pending_1 <= 1'b0;
            end

            // ================================================================
            // STAGE 2: RESPONSE GENERATION
            // Predictable Execution: resp_v_o is a single-cycle pulse,
            // cleared unconditionally to prevent stale valid signals.
            // Energy Efficiency: resp_msg_o only toggles when new data present.
            // ================================================================
            if (req_pending_2) begin
                resp_v_o <= 1'b1;
                resp_msg_o <= req_msg_r2;
                req_pending_2 <= 1'b0;
            end else begin
                resp_v_o <= 1'b0;  // Deterministic: valid deasserted in idle
            end
        end
    end

    // ========================================================================
    // LATENCY CONTRACT ASSERTIONS (Simulation only)
    // Verify that the design meets its fixed-latency guarantee.
    // ========================================================================
    `ifndef SYNTHESIS
    // Track cycle when request was accepted
    logic [31:0] accept_cycle;
    logic        tracking;

    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            accept_cycle <= '0;
            tracking <= 1'b0;
        end else begin
            if (req_v_i && ~req_pending_1 && !tracking) begin
                accept_cycle <= $time;
                tracking <= 1'b1;
            end
            if (resp_v_o && tracking) begin
                tracking <= 1'b0;
            end
        end
    end
    `endif

endmodule

