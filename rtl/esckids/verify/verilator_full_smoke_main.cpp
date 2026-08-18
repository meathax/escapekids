// Headless, project-owned Verilator runner for the full Escape Kids smoke top.
// The model receives its ROM/configuration plusargs from the invoking runner.
#include "Vtb_escape_kids_full_smoke.h"
#include "verilated.h"
#include <cstdio>
#include <memory>

double sc_time_stamp() { return 0.0; }

int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->threads(1);
    contextp->commandArgs(argc, argv);
    const std::unique_ptr<Vtb_escape_kids_full_smoke> top{
        new Vtb_escape_kids_full_smoke(contextp.get(), "")};

    while (!contextp->gotFinish()) {
        top->eval();
        if (!top->eventsPending()) break;
        contextp->time(top->nextTimeSlot());
    }

    top->final();
    return contextp->gotFinish() ? 0 : 1;
}
