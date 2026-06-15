// root_key_rom.sv
// Simple parameterized ROM containing root keys for the LPU Source of Trust.
// - KEY_WIDTH: width of each key in bits
// - KEY_DEPTH: number of keys stored
// Interface is a simple request/response: provide an index and assert read_v_i,
// the ROM returns data after one cycle with read_r_o asserted.

module root_key_rom #(
    parameter int KEY_WIDTH = 128,
    parameter int KEY_DEPTH = 4,
    parameter int ID_WIDTH = 2 // log2(KEY_DEPTH)
) (
    input  logic                   clk,
    input  logic                   rst_ni, // active-low reset (asserted low)

    // read request
    input  logic                   read_v_i,
    input  logic [ID_WIDTH-1:0]    idx_i,
    output logic                   read_r_o,

    // read response
    output logic [KEY_WIDTH-1:0]   key_o
);

    // Storage
    logic [KEY_WIDTH-1:0] mem [0:KEY_DEPTH-1];

    // Read staging register
    logic [KEY_WIDTH-1:0] key_r;
    logic read_pending;

    // Initialize with example constants. In production, these would be
    // instantiated from a hex/provisioning file or OTP.
    initial begin
        // Default example keys (128-bit) - change for real use.
        if (KEY_DEPTH > 0) mem[0] = 128'h0123_4567_89ab_cdef_0123_4567_89ab_cdef;
        if (KEY_DEPTH > 1) mem[1] = 128'hdead_beef_dead_beef_dead_beef_dead_beef;
        if (KEY_DEPTH > 2) mem[2] = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
        if (KEY_DEPTH > 3) mem[3] = 128'h9999_aaaa_bbbb_cccc_dddd_eeee_ffff_0000;
    end

    // Simple one-cycle read latency (request accepted one cycle, data returned
    // the next cycle). Keep outputs registered for timing.
    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            key_r <= '0;
            read_pending <= 1'b0;
            read_r_o <= 1'b0;
            key_o <= '0;
        end else begin
            // capture request
            read_pending <= read_v_i;
            if (read_v_i) begin
                // safe index clamp: if index out of range, return zero
                if (idx_i < KEY_DEPTH)
                    key_r <= mem[idx_i];
                else
                    key_r <= '0;
            end

            // drive response one cycle after request
            read_r_o <= read_pending;
            if (read_pending)
                key_o <= key_r;
            else
                key_o <= key_o; // hold
        end
    end

    // Simple protocol assertion: if read_v_i pulses, read_r_o should follow
    // within one cycle when not in reset.
    // s: use SystemVerilog assert for simulation-time checking
    `ifndef SYNTHESIS
    always_ff @(posedge clk) begin
        if (read_v_i)
            assert(read_r_o || rst_ni == 1'b0) else $error("root_key_rom: read_v_i asserted but read_r_o not asserted next cycle");
    end
    `endif

endmodule

