// Headless, project-owned Verilator runner for the exhaustive decode contract.
// No SDL, GUI, display, or host-time dependency is used.
#include "Vtb_escape_kids_map_contract.h"
#include "verilated.h"
#include <memory>
#include <cstdio>

double sc_time_stamp() { return 0.0; }

int main(int argc, char** argv) {
    std::fprintf(stderr, "ESCAPE_KIDS_VERILATOR_MAP_START\n");
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->threads(1);
    contextp->commandArgs(argc, argv);
    const std::unique_ptr<Vtb_escape_kids_map_contract> top{
        new Vtb_escape_kids_map_contract(contextp.get(), "")};

    while (!contextp->gotFinish() && contextp->time() < 100000000) {
        top->eval();
        if (!top->eventsPending()) break;
        contextp->time(top->nextTimeSlot());
    }

    top->final();
    const int rc = contextp->gotFinish() ? 0 : 1;
    std::fprintf(stderr, "ESCAPE_KIDS_VERILATOR_MAP_END finish=%d time=%llu rc=%d\n",
                 contextp->gotFinish() ? 1 : 0,
                 static_cast<unsigned long long>(contextp->time()), rc);
    return rc;
}
