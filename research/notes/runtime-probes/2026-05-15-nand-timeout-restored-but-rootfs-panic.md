# NAND timeout restored but rootfs still panics

## Result

Last RAM/TFTP check restored the NAND probe failure path, but the image still does not reach OpenWrt shell.

## Good sign

The expected NAND timeout baseline returned:

```text
bcm6368_nand 14e02200.nand: timeout waiting for command 0x9
bcm6368_nand 14e02200.nand: intfc status c0000000
nand: No NAND device found
This means the NAND probe path is active again.

Bad sign

The kernel still panics during initramfs/rootfs unpack before /init:

Unhandled kernel unaligned access
epc: inode_init_always_gfp+0x84/0x200
Call Trace:
inode_init_always_gfp
alloc_inode
new_inode
__shmem_get_inode
shmem_mknod
shmem_mkdir
vfs_mkdir
init_mkdir
do_name
write_buffer
unpack_to_rootfs
do_populate_rootfs
async_run_entry_fn
Kernel panic - not syncing: Fatal exception
Conclusion

This is not a working baseline yet.

Current state:

NAND timeout baseline restored.
SPI/HSSPI panic path no longer visible.
Rootfs/initramfs unpack panic remains.
No OpenWrt shell.
No /proc/mtd check possible.

Next session must first restore a shell-booting image before continuing NAND CS_SELECT or small-page NAND work.

Safety: RAM/TFTP only. No flash writes.
