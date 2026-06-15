// lpu_sot_top.sv
// Top-level glue for the LPU Source-of-Trust reference implementation.
// Wires together a small MMIO interface, access_control, root_key_rom and a
// handshake module to service key requests.

module lpu_sot_top #(
    parameter int KEY_WIDTH = 128,
    parameter int KEY_DEPTH = 4,
    parameter int ID_WIDTH = 2
) (
    input  logic clk,
    input  logic rst_ni,

    // mmio-like simple interface (used for testbench/programming the policy)
    input  logic                   mmio_wr_v_i,
    input  logic [7:0]             mmio_wr_addr_i,
    input  logic [31:0]            mmio_wr_data_i,
    input  logic                   mmio_rd_v_i,
    input  logic [7:0]             mmio_rd_addr_i,
    output logic [31:0]            mmio_rd_data_o,
    output logic                   mmio_rd_r_o,

    // request interface from a client (very small example)
    input  logic                   req_v_i,
    input  logic [31:0]            req_msg_i,
    output logic                   req_r_o,

    output logic                   resp_v_o,
    output logic [31:0]            resp_msg_o
);

    // Internal wires
    logic [31:0] mmio_rd_data;
    logic mmio_rd_r;

    logic access_allow;

    // Simple policy is stored in mmio addr 0
    mmio_if #(.ADDR_WIDTH(8), .DATA_WIDTH(32)) mmio (
        .clk(clk), .rst_ni(rst_ni),
        .wr_v_i(mmio_wr_v_i), .wr_addr_i(mmio_wr_addr_i), .wr_data_i(mmio_wr_data_i),
        .rd_v_i(mmio_rd_v_i), .rd_addr_i(mmio_rd_addr_i),
        .rd_data_o(mmio_rd_data_o), .rd_r_o(mmio_rd_r_o)
    );

    access_control #(.ID_WIDTH(ID_WIDTH)) ac (
        .clk(clk), .rst_ni(rst_ni),
        .client_id_i(req_msg_i[3:0][ID_WIDTH-1:0]), // low bits used as client id
        .op_i(2'b00), // read
        .policy_wr_v_i(mmio_wr_v_i && (mmio_wr_addr_i == 8'h0)),
        .policy_wr_data_i(mmio_wr_data_i),
        .allow_o(access_allow)
    );

    // Simple key ROM
    root_key_rom #(.KEY_WIDTH(KEY_WIDTH), .KEY_DEPTH(KEY_DEPTH), .ID_WIDTH(ID_WIDTH)) rk (
        .clk(clk), .rst_ni(rst_ni),
        .read_v_i(req_v_i && access_allow),
        .idx_i(req_msg_i[ID_WIDTH-1:0]),
        .read_r_o(),
        .key_o(/* not directly exposed here */)
    );

    // Handshake: for demonstration we echo permitted requests with a small
    // status in the response. Production design would return the key using a
    // secure path and not expose keys on open interfaces.
    lpu_handshake h (
        .clk(clk), .rst_ni(rst_ni),
        .req_v_i(req_v_i && access_allow), .req_msg_i(req_msg_i), .req_r_o(req_r_o),
        .resp_v_o(resp_v_o), .resp_msg_o(resp_msg_o)
    );

    // Note: For a real product the key would be returned via a secure
    // dedicated interface to authorized consumers only. This reference keeps
    // the top-level interface minimal for demonstration purposes.

endmodule


