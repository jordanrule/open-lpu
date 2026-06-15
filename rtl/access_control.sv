// access_control.sv
// A tiny, parameterized access control unit. It receives a client ID and an
// operation code and consults a simple policy register (bitmask) to allow or
// deny access. This is intentionally minimal and intended as a reference.

module access_control #(
    parameter int ID_WIDTH = 2,
    parameter int POLICY_WIDTH = (1 << ID_WIDTH)
) (
    input  logic                   clk,
    input  logic                   rst_ni,

    // inputs
    input  logic [ID_WIDTH-1:0]    client_id_i,
    input  logic [1:0]             op_i, // 0=read, 1=write, others reserved

    // policy programming (a simple write interface for demonstration)
    input  logic                   policy_wr_v_i,
    input  logic [POLICY_WIDTH-1:0] policy_wr_data_i,

    // output
    output logic                   allow_o
);

    // Single policy register that encodes allowed clients for read op.
    logic [POLICY_WIDTH-1:0] policy_r;

    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            policy_r <= '0;
            allow_o <= 1'b0;
        end else begin
            if (policy_wr_v_i) policy_r <= policy_wr_data_i;

            // For this simple example, we only gate read operations.
            if (op_i == 2'b00) begin
                allow_o <= policy_r[client_id_i];
            end else begin
                allow_o <= 1'b0; // other ops not allowed in this reference
            end
        end
    end

    `ifndef SYNTHESIS
    // Sanity check: policy width must be compatible with ID_WIDTH
    initial begin
        if (POLICY_WIDTH != (1 << ID_WIDTH)) begin
            $warning("access_control: POLICY_WIDTH (%0d) not equal to 2^ID_WIDTH (2^%0d).", POLICY_WIDTH, ID_WIDTH);
        end
    end
    `endif

endmodule

