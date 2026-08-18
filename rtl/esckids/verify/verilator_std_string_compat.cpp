// Simulation-only compatibility adapter for the installed MSYS2 UCRT64
// toolchain.  GCC 16.1's headers emit the C4 base-object spelling for the
// std::string move constructor, while the installed libstdc++ exports the
// equivalent C1/C2 spellings.  This weak forwarding symbol does not change
// the C++ ABI or synthesized RTL; it is included only by project-owned
// Verilator builds and may be removed when the toolchain is repaired.
extern "C" void escape_kids_std_string_c1(void* self, void* other)
    asm("_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC1EOS4_");

extern "C" __attribute__((weak)) void escape_kids_std_string_c4(void* self, void* other)
    asm("_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEC4EOS4_");

extern "C" __attribute__((weak)) void escape_kids_std_string_c4(void* self, void* other) {
    escape_kids_std_string_c1(self, other);
}
