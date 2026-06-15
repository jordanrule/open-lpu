// Simple Verilator C++ test harness for lpu_sot_top
// Build with verilator and run to exercise mmio programming and request/response

#include <verilated.h>
#include "Vlpu_sot_top.h"
#include <iostream>
#include <cassert>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vlpu_sot_top* top = new Vlpu_sot_top;

    // initialize inputs
    top->clk = 0;
    top->rst_ni = 0; // active low
    top->mmio_wr_v_i = 0;
    top->mmio_rd_v_i = 0;
    top->req_v_i = 0;

    // run reset for a few cycles
    for (int i = 0; i < 4; ++i) {
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
    }

    // deassert reset
    top->rst_ni = 1;
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();

    // Initially deny all clients: write policy = 0
    top->mmio_wr_addr_i = 0x0;
    top->mmio_wr_data_i = 0x0;
    top->mmio_wr_v_i = 1;
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
    top->mmio_wr_v_i = 0;

    // Try requesting as client id 1 -> should be denied (no response)
    top->req_msg_i = 1;
    top->req_v_i = 1;
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
    top->req_v_i = 0;

    // run a few cycles and check response
    bool resp_seen = false;
    for (int i = 0; i < 10; ++i) {
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
        if (top->resp_v_o) resp_seen = true;
    }
    if (resp_seen) {
        std::cerr << "ERROR: Denied client unexpectedly received response\n";
        delete top; return 1;
    } else {
        std::cout << "Denied client correctly received no response\n";
    }

    // Allow client 1 by writing policy bit 1
    top->mmio_wr_addr_i = 0x0;
    top->mmio_wr_data_i = 0x2;
    top->mmio_wr_v_i = 1;
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
    top->mmio_wr_v_i = 0;

    // Request as client 1 again
    top->req_msg_i = 1;
    top->req_v_i = 1;
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
    top->req_v_i = 0;

    // wait for response
    resp_seen = false;
    for (int i = 0; i < 20; ++i) {
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
        if (top->resp_v_o) {
            resp_seen = true;
            std::cout << "Allowed client received response: msg=0x" << std::hex << (uint32_t)top->resp_msg_o << std::dec << "\n";
            break;
        }
    }
    if (!resp_seen) {
        std::cerr << "ERROR: Allowed client did not receive a response\n";
        delete top; return 2;
    }

    std::cout << "Test PASSED\n";
    delete top;
    return 0;
}

