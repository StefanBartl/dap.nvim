/*
 * Debuggee of scripts/memory-gdb-check.lua (the manual end-to-end check of the
 * memory view against a real GDB). Not part of the spec suite.
 *
 * The check stops on the marked line, reads `buffer` through the memory view,
 * writes buffer[1] = 'Z' through it and continues: the exit code is 0 only if
 * that write reached the running program.
 *
 * `image_start` points at the first byte of the executable's image (the PE
 * header on Windows, the ELF header on Linux): the start of a mapping, with
 * nothing mapped right before it -- where the view's context read must fall
 * back to the target itself. The linker symbols it is taken from carry no
 * debug info, so GDB only sees them through this pointer.
 */
#include <stdio.h>

#ifdef _WIN32
extern char __ImageBase;
const void *image_start = &__ImageBase;
#else
extern char __executable_start;
const void *image_start = &__executable_start;
#endif

unsigned char buffer[32] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345";

int main(void) {
    volatile int seen = 0;
    buffer[0] = 'A';
    seen = buffer[1]; /* BREAK HERE (stops before this line runs) */
    printf("buffer[1] = %c\n", seen);
    return seen == 'Z' ? 0 : 1;
}
