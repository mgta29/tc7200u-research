# 2026-06-16-011656 rdinit shell no-pipe diagnostic passed

- serial_log: records/logs/serial/picocom-20260616-010159.log
- verdict: rdinit shell, BusyBox, cp, and pipeline are stable when commands are sent cleanly
- conclusion: failure is specific to /init/preinit/switch_root path, not general libc/malloc

## Markers
922:[   87.634395] Run /bin/sh as init process
930:BusyBox v1.37.0 (2026-01-02 17:07:02 UTC) built-in shell (ash)
935:~ # echo DIAG_1
936:DIAG_1
937:~ # cat /proc/meminfo
975:~ # echo DIAG_2
976:DIAG_2
977:~ # head -30 /proc/meminfo
1008:~ # echo DIAG_3
1009:DIAG_3
1010:~ # /bin/cp --help
1011:BusyBox v1.37.0 (2026-01-02 17:07:02 UTC) multi-call binary.
1031:~ # echo DIAG_4
1032:DIAG_4
1033:~ # /bin/cp /init /tmp/init.copy
1034:~ # echo DIAG_5
1035:DIAG_5
1036:~ # ls -l /tmp/init.copy
1038:~ # cat /proc/meminfo | head -30
