// mmio_if.sv
// Management MMIO Interface for LPU Source of Trust
//
// Provides simple register access for policy programming and status queries:
// - Decoupled from main data plane (low-latency key access path)
// - Management traffic independent of key requests (predictable performance)
// - Minimal logic footprint (cost-efficient)
// - Supports 256 address space with 32-bit data width (standard for LPU chips)
//
// Register Map (in this reference implementation):
//   0x0 : POLICY (RW) - Bitmask of allowed clients (bit[i]=1 allows client i)
//   0x4 : STATUS  (RW) - Status/debug register
//
// Note: This is NOT a replacement for a full bus protocol (e.g., TileLink, APB).
// For production integration into a larger SoC, use proper bus infrastructure.

module mmio_if #(
    parameter int ADDR_WIDTH = 8,             // Address space (8 bits = 256 locations)
    parameter int DATA_WIDTH = 32             // Data width (standard for LPU mgmt)
) (
    input  logic                        clk,
    input  logic                        rst_ni,       // Active-low async reset

    // ========================================================================
    // WRITE INTERFACE (Management Plane)
    // For programming policy and status registers
    // ========================================================================
    input  logic                        wr_v_i,                   // Write valid
    input  logic [ADDR_WIDTH-1:0]       wr_addr_i,                // Write address
    input  logic [DATA_WIDTH-1:0]       wr_data_i,                // Write data

    // ========================================================================
    // READ INTERFACE (Management Plane)
    // For querying status and policy
    // ========================================================================
    input  logic                        rd_v_i,                   // Read valid
    input  logic [ADDR_WIDTH-1:0]       rd_addr_i,                // Read address
    output logic [DATA_WIDTH-1:0]       rd_data_o,                // Read response data
    output logic                        rd_r_o                    // Read response ready
);

    // ========================================================================
    // REGISTER FILE (Small policy/status storage)
    // Kept separate from main SoT datapath to avoid timing interference
    // ========================================================================
    logic [DATA_WIDTH-1:0] reg_policy;    // Policy register (who can read keys)
    logic [DATA_WIDTH-1:0] reg_status;    // Status/debug register

    // ========================================================================
    // SYNCHRONOUS REGISTER UPDATES
    // Async reset (assert) with sync de-assert for clean initialization.
    // Low Latency: single-cycle write commit, single-cycle read response.
    // Predictable Execution: rd_r_o is a pulse (cleared when no read pending).
    // Energy Efficiency: output register only toggles on active read request.
    // ========================================================================
    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            // Safe reset state: deny all access, zero status
            reg_policy <= '0;
            reg_status <= '0;
            rd_data_o <= '0;
            rd_r_o <= 1'b0;
        end else begin
            // ================================================================
            // WRITE PATH (Policy and Status Programming)
            // Low Latency: write takes effect same cycle (available next read)
            // ================================================================
            if (wr_v_i) begin
                unique case (wr_addr_i)
                    8'h0: reg_policy <= wr_data_i;    // Write to POLICY register
                    8'h4: reg_status <= wr_data_i;    // Write to STATUS register
                    default: ;                        // Undefined addresses ignored
                endcase
            end

            // ================================================================
            // READ PATH (Register Readback)
            // Predictable Execution: rd_r_o asserted for exactly 1 cycle
            // per read request, then cleared unconditionally.
            // Energy Efficiency: rd_data_o only updates when rd_v_i active,
            // avoiding unnecessary switching on the output bus.
            // ================================================================
            rd_r_o <= rd_v_i;
            if (rd_v_i) begin
                unique case (rd_addr_i)
                    8'h0: rd_data_o <= reg_policy;    // Read from POLICY
                    8'h4: rd_data_o <= reg_status;    // Read from STATUS
                    default: rd_data_o <= '0;         // Undefined addresses return 0
                endcase
            end
            // Energy: rd_data_o holds value when idle (no spurious toggling)
        end
    end

    // ========================================================================
    // DESIGN NOTES (Energy/Cost Efficiency)
    // ========================================================================
    // 1. Minimal address decode (only two registers used in this reference)
    // 2. Single-cycle read latency (no multi-stage pipelines)
    // 3. Simple combinatorial mux for register select
    // 4. Async assert / sync de-assert reset minimizes reset tree complexity
    // 5. Completely decoupled from main data path for timing closure

endmodule

