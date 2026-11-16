typedef unsigned int u32;
#define REG(a) (*(volatile u32 *)(a))
#define VIDEO_MODE REG(0x10003000u)
#define MAILBOX REG(0x10004000u)
#define CYCLES REG(0x10004004u)
#define RAM_RESULT REG(0x10004008u)
#define KEY_STATUS REG(0x1000400cu)
#define LAST_KEY REG(0x10004010u)
#define KEY_COUNT REG(0x10004014u)
#define ERROR_CODE REG(0x10004018u)
#define KEYS_STATUS REG(0x10002004u)
#define KEYS_EVENT REG(0x10002000u)
static volatile u32 initialized = 0x13579bdf;
static volatile u32 zeroed;
// Linker-owned scratch, disjoint from initialized data, other BSS and stack.
static volatile u32 scratch[1024];
static int ram_test(void) {
    // Separate write/read sweeps catch address aliasing and stuck data bits.
    for (u32 pass=0; pass<4; ++pass) {
        for (u32 i=0; i<1024; ++i) {
            u32 p = pass==0 ? 0u : pass==1 ? ~0u :
                    (0xa5a50000u ^ (i * 0x01010101u));
            scratch[i] = pass==3 ? ~p : p;
        }
        for (u32 i=0; i<1024; ++i) {
            u32 p = pass==0 ? 0u : pass==1 ? ~0u :
                    (0xa5a50000u ^ (i * 0x01010101u));
            if (scratch[i] != (pass==3 ? ~p : p)) return 0;
        }
    }
    return 1;
}
int main(void) {
    VIDEO_MODE = 3;
    RAM_RESULT = 0;
    if (initialized != 0x13579bdf || zeroed != 0) {
        ERROR_CODE = 0xe001;
        __asm__ volatile("ebreak");
    }
    zeroed = 0x2468ace0;
    MAILBOX = 1;
    if (ram_test()) RAM_RESULT = 1;
    else { RAM_RESULT = 2; ERROR_CODE = 0xe002; }
    u32 heartbeat=1, count=0, tick=CYCLES;
    for (;;) {
        // No hardware increment and no dependence on VGA frame progress.
        u32 now=CYCLES;
        if ((u32)(now-tick)>=500000u) {
            MAILBOX = ++heartbeat;
            tick=now;
        }
        u32 status=KEYS_STATUS;
        KEY_STATUS=status;
        // Preserve sticky error evidence; do not silently clear/flush events.
        if (RAM_RESULT!=2) {
            if (status & 0x400u) ERROR_CODE=0xe004;
            else if (status & 0x200u) ERROR_CODE=0xe003;
        }
        if (status & 0x100u) {
            u32 event=KEYS_EVENT;
            if (event & 0x80000000u) {
                LAST_KEY=event & 0x1ffu;
                KEY_COUNT=++count;
            }
        }
    }
}
