// mmio_if.sv
// Very small MMIO/CSR shim used for the reference SoT. This is NOT a
// replacement for a project bus (e.g. TL-UL / APB) but provides a simple
// write/read interface for simulation and early integration.

module mmio_if #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
) (
    input  logic                   clk,
    input  logic                   rst_ni,

    // simple register interface
    input  logic                   wr_v_i,
    input  logic [ADDR_WIDTH-1:0]  wr_addr_i,
    input  logic [DATA_WIDTH-1:0]  wr_data_i,

    input  logic                   rd_v_i,
    input  logic [ADDR_WIDTH-1:0]  rd_addr_i,
    output logic [DATA_WIDTH-1:0]  rd_data_o,
    output logic                   rd_r_o
);

    // Tiny register file used for policy and status. For the reference
    // we expose two registers:
    // addr 0x0 : policy low bits (supports up to 32 clients in this ref)
    // addr 0x4 : status

    logic [DATA_WIDTH-1:0] reg_policy;
    logic [DATA_WIDTH-1:0] reg_status;

    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            reg_policy <= '0;
            reg_status <= '0;
            rd_data_o <= '0;
            rd_r_o <= 1'b0;
        end else begin
            if (wr_v_i) begin
                unique case (wr_addr_i)
                    'h0: reg_policy <= wr_data_i;
                    'h4: reg_status <= wr_data_i;
                    default: ;
                endcase
            end

            rd_r_o <= rd_v_i;
            if (rd_v_i) begin
                unique case (rd_addr_i)
                    'h0: rd_data_o <= reg_policy;
                    'h4: rd_data_o <= reg_status;
                    default: rd_data_o <= '0;
                endcase
            end
        end
    end

endmodule

