# SPI disabled but kernel still panics during rootfs unpack

## Result

Last RAM/TFTP test for the day.

SPI/HSSPI no longer probed before panic, so disabling the SPI node removed the previous SPI probe path.

However, the kernel still panicked before `/init` and before OpenWrt shell.

## Observed panic

```text
Unhandled kernel unaligned access
CPU: 0 PID: 22 Comm: kworker/u4:1
Hardware name: Technicolor TC7200.U
epc: inode_init_always_gfp+0x84/0x200
Call Trace:
inode_init_always_gfp
alloc_inode
new_inode
__shmem_get_inode
shmem_mknod
path_openat
do_name
write_buffer
unpack_to_rootfs
do_populate_rootfs
async_run_entry_fn
Kernel panic - not syncing: Fatal exception
NAND/SPI evidence
No spi-nor / hsspi probe lines before panic.
No bcm6368_nand probe line before panic.
No NAND timeout line before panic.
No shell reached, so /proc/mtd could not be checked.
Conclusion

This is not valid evidence for or against NAND detection. The current image/rootfs/build baseline is still broken because it panics during initramfs/rootfs unpack before normal runtime checks.

Next step should restore a known-good booting baseline before continuing NAND CS_SELECT or small-page NAND tests.

Safety: RAM/TFTP only. No flash writes.
