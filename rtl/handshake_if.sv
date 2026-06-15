// handshake_if.sv
// Simple request/response handshake helper module. Intended to demonstrate
// a small valid/ready-style interaction for requesting keys.

module lpu_handshake (
    input  logic clk,
    input  logic rst_ni,

    // request side
    input  logic req_v_i,
    input  logic [31:0] req_msg_i,
    output logic req_r_o,

    // response side
    output logic resp_v_o,
    output logic [31:0] resp_msg_o
);

    // Simple flow control: we accept a request only when not busy
    logic busy;

    always_ff @(posedge clk or negedge rst_ni) begin
        if (!rst_ni) begin
            busy <= 1'b0;
            req_r_o <= 1'b0;
            resp_v_o <= 1'b0;
            resp_msg_o <= '0;
        end else begin
            // Accept new request when not busy
            if (req_v_i && !busy) begin
                busy <= 1'b1;
                req_r_o <= 1'b1;
                // Simple echo behavior by default; higher-level module should
                // override response handling by connecting resp_* signals.
                resp_msg_o <= req_msg_i;
                resp_v_o <= 1'b1;
            end else begin
                req_r_o <= 1'b0;
                // clear response once observed
                if (resp_v_o) begin
                    busy <= 1'b0;
                    resp_v_o <= 1'b0;
                end
            end
        end
    end

endmodule

