`timescale 1ns/1ps
module lpu_sot_tb;
    logic clk;
    logic rst_ni;

    // mmio
    logic mmio_wr_v;
    logic [7:0] mmio_wr_addr;
    logic [31:0] mmio_wr_data;
    logic mmio_rd_v;
    logic [7:0] mmio_rd_addr;
    logic [31:0] mmio_rd_data;
    logic mmio_rd_r;

    // request / response
    logic req_v;
    logic [31:0] req_msg;
    logic req_r;
    logic resp_v;
    logic [31:0] resp_msg;

    // instantiate DUT
    lpu_sot_top dut (
        .clk(clk), .rst_ni(rst_ni),
        .mmio_wr_v_i(mmio_wr_v), .mmio_wr_addr_i(mmio_wr_addr), .mmio_wr_data_i(mmio_wr_data),
        .mmio_rd_v_i(mmio_rd_v), .mmio_rd_addr_i(mmio_rd_addr), .mmio_rd_data_o(mmio_rd_data), .mmio_rd_r_o(mmio_rd_r),
        .req_v_i(req_v), .req_msg_i(req_msg), .req_r_o(req_r),
        .resp_v_o(resp_v), .resp_msg_o(resp_msg)
    );

    // clock
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz-ish

    initial begin
        $dumpfile("build/lpu_sot.vcd");
        $dumpvars(0, lpu_sot_tb);

        // reset
        rst_ni = 1'b0;
        mmio_wr_v = 1'b0; mmio_rd_v = 1'b0;
        req_v = 1'b0;
        #20;
        rst_ni = 1'b1;

        // Initially deny all clients
        mmio_wr_addr = 8'h0; mmio_wr_data = 32'h0; mmio_wr_v = 1'b1;
        @(posedge clk);
        mmio_wr_v = 1'b0;
        $display("Programmed policy = 0x%08x", mmio_wr_data);

        // Try to request key as client id 1 -> should be denied (no resp)
        req_msg = 32'd1; req_v = 1'b1;
        @(posedge clk);
        req_v = 1'b0;
        #20;
        if (resp_v) $error("Denied client unexpectedly received response");
        else $display("Denied client correctly received no response");

        // Allow client 1 by writing policy bit 1
        mmio_wr_addr = 8'h0; mmio_wr_data = 32'hF; mmio_wr_v = 1'b1; // Try all ones
        @(posedge clk);
        mmio_wr_v = 1'b0;
        $display("[TB] After MMIO write cycle 1: policy_r=0x%x", dut.access_control_inst.policy_r);
        @(posedge clk);
        $display("[TB] After MMIO write cycle 2: policy_r=0x%x", dut.access_control_inst.policy_r);
        $display("Programmed policy = 0x%08x", 32'h2);

        // Request again as client id 1 -> should get a response
        $display("Setting up request: policy should be 0x2 for client 1");
        $display("Access control policy_r = 0x%x", dut.access_control_inst.policy_r);
        req_msg = 32'd1; req_v = 1'b1;
        @(posedge clk);
        $display("Cycle after request: req_r=%0d, resp_v=%0d, allow=%0d, policy_r=0x%x",
                 req_r, resp_v, dut.access_control_inst.policy_r, dut.access_control_inst.policy_r);
        req_v = 1'b0;
        // wait cycles for handshake response (should be ~2 cycles)
        // resp_v_o is a single-cycle pulse (predictable execution), so capture it
        begin
            logic got_resp;
            logic [31:0] captured_msg;
            got_resp = 1'b0;
            captured_msg = '0;
            repeat (5) begin
                @(posedge clk);
                $display("Wait cycle: resp_v=%0d, resp_msg=0x%08x", resp_v, resp_msg);
                if (resp_v && !got_resp) begin
                    got_resp = 1'b1;
                    captured_msg = resp_msg;
                end
            end
            if (!got_resp) $error("Allowed client did not receive a response");
            else $display("Allowed client received response: msg=0x%08x", captured_msg);
        end

        $display("Testbench finished");
        $finish;
    end

endmodule

