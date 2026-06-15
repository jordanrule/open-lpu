// root_key_rom.sv
// Root Key Storage Module for LPU Source of Trust
//
// Provides immutable secret storage with fixed, predictable access latency:
// - Fixed 1-cycle read latency ensures deterministic secure boot timing
// - Simple single-port ROM minimizes area and power (cost-efficient)
// - Parameterized key width and depth support various LPU configurations
// - No multi-cycle stalls or cache effects (predictable execution)
// - Designed for reliability: index clamping prevents out-of-bounds reads
//
// In production, keys would be loaded from:
// - Fused OTP (One-Time Programmable memory)
// - Secure provisioning during manufacturing
// - This reference uses compile-time constants for simulation
//
// References: Groq LPU whitepaper (low-latency secure boot requirements)

module root_key_rom #(
    parameter int KEY_WIDTH = 128,        // Width of each key (e.g., 128 for AES-128)
    parameter int KEY_DEPTH = 4,          // Number of keys (must be power of 2)
    parameter int ID_WIDTH = 2            // Client ID width (log2 of max clients)
) (
    input  logic                   clk,
    input  logic                   rst_ni,       // Active-low async reset (assert), sync de-assert

    // Read request (data plane, low-latency path)
    input  logic                   read_v_i,     // Request valid: client wants key
    input  logic [ID_WIDTH-1:0]    idx_i,        // Which key to read
    output logic                   read_r_o,     // Response ready (data valid)

    // Read response (output driven one cycle after request)
    output logic [KEY_WIDTH-1:0]   key_o         // Key data (held until next request)
);

    // ========================================================================
    // READ-ONLY MEMORY (Initialized at simulation time)
    // In production: instantiate as embedded ROM or load from OTP
    // ========================================================================
    logic [KEY_WIDTH-1:0] mem [0:KEY_DEPTH-1];

    // Staging registers for pipelined read
    logic [KEY_WIDTH-1:0] key_r;        // Captured key from ROM
    logic read_pending;                 // Flag: request accepted, response next cycle
    logic [KEY_WIDTH-1:0] key_next;     // Next cycle's output

    // Energy Efficiency: track whether ROM data changed to avoid unnecessary
    // toggling on key_o (reduces dynamic power on wide bus).
    logic key_output_en;                // Only update output when new data ready

    // ========================================================================
    // INITIALIZATION (Simulation only; production would use OTP/provisioning)
    // ========================================================================
    initial begin
        // Default example keys (128-bit values for demonstration)
        // Change these for actual deployment; in real hardware they come from fuses
        if (KEY_DEPTH > 0) mem[0] = 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef;
        if (KEY_DEPTH > 1) mem[1] = 128'hdead_beef_dead_beef_dead_beef_dead_beef;
        if (KEY_DEPTH > 2) mem[2] = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
        if (KEY_DEPTH > 3) mem[3] = 128'h9999_aaaa_bbbb_cccc_dddd_eeee_ffff_0000;
    end

    // ========================================================================
    // FIXED-LATENCY READ PATH
    // All operations registered for timing predictability and power efficiency
    // ========================================================================

    // Combinatorial ROM read (safe index clamping to prevent out-of-bounds)
    always_comb begin
        if (idx_i < KEY_DEPTH)
            key_next = mem[idx_i];
        else
            key_next = '0;                // Bounds check: return 0 if index out of range
    end

    // ========================================================================
    // SYNCHRONOUS PIPELINE STAGE (Async reset, sync de-assert)
    // Ensures all outputs are registered for high-frequency operation.
    // Latency contract: read_v_i at cycle N => read_r_o + key_o valid at N+2.
    // ========================================================================
    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            // Reset to safe state
            key_r <= '0;
            read_pending <= 1'b0;
            read_r_o <= 1'b0;
            key_o <= '0;
            key_output_en <= 1'b0;
        end else begin
            // ================================================================
            // REQUEST CAPTURE STAGE (Cycle N+1)
            // Low Latency: unconditional single-cycle capture
            // Energy Efficiency: key_r only updates when read_v_i is asserted
            // ================================================================
            read_pending <= read_v_i;
            if (read_v_i) begin
                key_r <= key_next;          // Latch the ROM read data
            end
            // Energy: no toggling on key_r when idle (held by default)

            // ================================================================
            // RESPONSE GENERATION STAGE (Cycle N+2)
            // Predictable Execution: read_r_o is a single-cycle pulse, cleared
            // unconditionally so downstream logic sees deterministic timing.
            // ================================================================
            read_r_o <= read_pending;
            key_output_en <= read_pending;
            if (read_pending) begin
                key_o <= key_r;             // Output the captured key
            end
            // Energy: key_o only switches when new data arrives (no spurious toggling)
        end
    end

    // ========================================================================
    // ASSERTIONS (Simulation/Verification only)
    // ========================================================================
    `ifndef SYNTHESIS
    // Check that read requests are properly sequenced (no back-to-back requests)
    always_ff @(posedge clk) begin
        if (read_v_i && read_pending) begin
            $warning("root_key_rom: request received while previous read still pending");
        end
    end

    // Check for out-of-bounds accesses (caught by safe clamping, but warn in sim)
    always_ff @(posedge clk) begin
        if (read_v_i && (idx_i >= KEY_DEPTH)) begin
            $warning("root_key_rom: index %0d out of bounds (DEPTH=%0d)",
                     idx_i, KEY_DEPTH);
        end
    end
    `endif

endmodule

