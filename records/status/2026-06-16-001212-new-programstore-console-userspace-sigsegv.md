# 2026-06-16-001212 new ProgramStore console candidate userspace SIGSEGV

## Candidate
- filename: openwrt-console-procd-20260615-232607.bin
- serial_log: records/logs/serial/picocom-20260615-235913.log
- gate_report: records/logs/builds/2026-06-16-000925-check-gates-picocom-20260615-235913.txt
- verdict: wrapper/CRC/UART passed; userspace failed before procd/login

## Key evidence
50:Enter filename [tc7200-console-known-good-retest.bin]: openwrt-console-procd-20260615-232607.bin
56:Starting TFTP of openwrt-console-procd-20260615-232607.bin from 192.168.77.2
88: File Length: 7143509 bytes
89:Load Address: 82000000
91:         HCS: ed29
92:         CRC: 00000000
96:Bypassing CRC Verifiction on Image 4...
97:CRC time = 314
121:[    0.000000] Linux version 6.12.87 (mgta29@CerberusNB) (mips-openwrt-linux-musl-gcc (OpenWrt GCC 14.3.0 r34703-aa96b3ad55) 14.3.0, GNU ld (GNU Binutils) 2.44) #0 SMP Tue May 12 23:59:29 2026
124:[    0.000000] earlycon: bcm63xx_uart0 at MMIO 0x14e00500 (options '')
147:[    0.000000] Kernel command line: console=ttyS0,115200 earlycon ignore_loglevel loglevel=8 initcall_debug clk_ignore_unused pd_ignore_unused initramfs_async=0 panic=10
552:[   17.459270] calling  populate_rootfs+0x0/0x68 @ 1
553:[   71.586078] initcall populate_rootfs+0x0/0x68 returned 0 after 54117743 usecs
707:[   76.122547] 14e00500.serial: ttyS0 at MMIO 0x14e00500 (irq = 8, base_baud = 1687500) is a bcm63xx_uart
708:[   76.138822] printk: legacy console [ttyS0] enabled
709:[   76.138822] printk: legacy console [ttyS0] enabled
929:[   87.663121] Run /init as init process
935:[   95.027010] do_page_fault(): sending SIGSEGV to cp for invalid write access to 00000000
936:[   95.039924] epc = 77de5070 in libc.so[35070,77db0000+b9000]
937:[   95.052784] ra  = 77de51d4 in libc.so[351d4,77db0000+b9000]
939:[   95.589134] do_page_fault(): sending SIGSEGV to switch_root for invalid write access to 00000000
940:[   95.604634] epc = 77d818a8 in libc.so[358a8,77d4c000+b9000]
941:[   95.616317] ra  = 77d81718 in libc.so[35718,77d4c000+b9000]
942:[   95.630251] Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b
