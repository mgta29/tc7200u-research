# Executive Summary

The Technicolor TC7200 is a Euro‑DOCSIS 3.0 cable gateway (modem/router) built on a Broadcom-based platform.  It features a Broadcom BCM3383 SoC (dual-core BMIPS4350 at ~637 MHz) with 128 MiB DDR RAM, 64 MiB NAND flash, and a 1 MiB SPI flash.  Networking hardware includes a 4×1 Gbps Ethernet switch (BCM53124) and a single 2.4 GHz 802.11b/g/n radio (Broadcom BCM43227 2×2 via mini‑PCIe).  A 4‑pin 3.3 V TTL header (J305) exposes a 115200 8N1 serial console (pins: 3.3 V, TX, GND, RX)【24†L29-L35】【21†L25-L28】.  The bootloader is Broadcom’s BFC (LVG) bootloader version 2.4.0alpha18p1【26†L122-L130】, stored in SPI flash, which supports dual‑flash operation and can load firmware images from NAND.  The bootlog shows 128 MiB RAM at 0x8000_0000, with kernel and rootfs images at specific offsets and a pre‑configured partition map【26†L117-L125】【67†L522-L530】.  

Technicolor provides GPL-compliant source drops (for TC72xx series, e.g. TC7200/7210/7230) on GitHub【74†L291-L300】, including a prebuilt toolchain tarball.  However, this is for vendor Linux partitions (LxG OS) and not an OpenWrt build.  There is currently **no official OpenWrt target** or firmware for the TC7200.  Existing “support” is limited to community efforts: for example, a Linux port by an individual (jclehner) and Broadcom utility tools (bcm2dump/bcm2cfg) that recognize the TC7200【67†L531-L539】.  Porting OpenWrt will require custom work: generating a device tree or board DTS, adapting the Broadcom kernel drivers, and likely falling back to open-source alternatives (or omitting proprietary features). 

Key porting steps include accessing the serial console, dumping original firmware (e.g. via `bcm2dump`【67†L531-L539】), identifying NAND/SPI partitions, setting up a compatible MIPS toolchain (the vendor provides a GCC toolchain in its source package【74†L293-L300】), and building kernel and rootfs images.  The Broadcom DOCSIS modem core (eCos firmware) will **not** run under OpenWrt, so the port should focus on routing/Wi-Fi functions.  Risks include missing wireless drivers (Broadcom Wi-Fi requires proprietary blobs), legal issues around DOCSIS firmware (Broadcom code is under restricted licenses), and the possibility of voiding ISP certifications.  

**Sources:** Broadcom datasheets and FCC filings indicate the hardware specs; WikiDevi documents the bootloader and partition layout【26†L122-L129】【67†L531-L539】.  Community logs (Hackaday, OpenWrt forum) detail serial pinouts and utility tools【21†L25-L28】【67†L531-L539】. Technicolor’s GitHub provides build scripts and toolchains for TC72xx (the basis for kernel/rootfs)【74†L291-L300】.  This report collates and compares these sources, summarizing hardware variants and firmware versions in tables and illustrating the boot/flash flow and development steps (see diagrams).

## 1. Hardware Specifications

- **SoC/CPU:** Broadcom BCM3383 (BCM3383Z-B0), dual BMIPS4350 cores @ ~637 MHz【26†L117-L125】.  This is a cable‑gateway SoC combining full-band DOCSIS modem + networking.
- **RAM:** 128 MiB DDR (Samsung K4B1G1646G)【24†L33-L36】.
- **Flash:** 64 MiB NAND (Micron NAND512W3A2SN6E) plus 1 MiB SPI NOR (Macronix MX25L8008E)【24†L29-L35】.
- **Wireless:** One half‑miniPCIe slot with Broadcom BCM943227HM4L module (BCM43227 2×2:2, 2.4 GHz 802.11b/g/n, 300 Mbps)【24†L42-L49】.  (The hardware supports dual‑band; some variants use a second slot or 5 GHz card – see *Variants* below.)
- **Ethernet:** 4×1 Gbps ports via Broadcom BCM53124 Ethernet switch (plus 1×WAN via the cable modem interface)【24†L49-L52】.
- **USB:** 1×USB 2.0 host port (device variant dependent).
- **Serial:** 4-pin TTL header J305 (3.3 V, TX, GND, RX), 115200 bps, 8N1【24†L39-L41】【21†L25-L28】.
- **JTAG/Debug:** One 4-pin “programming” header (location near the main SoC) appears on PCB reviews (likely for ISP factory use).  Its exact pinout isn’t documented, but community photos show 4 pins labeled “JTAG” (though true 6-pin JTAG isn’t present)【42†L125-L134】.  In practice, serial console is used for recovery and hacking.
- **Power:** 12 V⎓, ~1.5 A (barrel connector).

**Variants:** Several TC7200 models exist (unbranded, ISP-branded, EMTA vs. non-EMTA), all with essentially the same hardware block【24†L91-L99】.  Key variants:
  - *TC7200:* Unbranded, concurrent dual-band Wi-Fi.
  - *TC7200.20:* Single-radio variant (selectable 2.4 GHz or 5 GHz, “.20” firmware name)【62†L53-L61】【62†L72-L79】.
  - *TC7200.U:* UPC-branded (may have locked firmware, no bridge mode).
  - *TC7200.d:* “No-voice” variant (no eMTA, EMTA disabled).
  - *TC7300:* Similar PCB (no USB, no on/off switch)【26†L197-L203】.
  - *Detection:* Model is usually printed on label (TC7200 vs .20 vs U).  Bootlog or firmware filenames also hint: e.g. “CF.01.xx” vs “STDD.01.xx” (see **Firmware Versions** below).

## 2. Bootloader, Recovery, and Serial Console

The TC7200 uses Broadcom’s proprietary “BFC” bootloader (also called LVG bootloader) version **2.4.0alpha18p1**【26†L122-L130】.  On power-up, it initializes DDR and storage (NOR/SPI and NAND) and prints a boot log over UART.  Key points:

- **Storage initialization:** Bootloader identifies the 1 MiB SPI NOR and the 64 MiB NAND (serial flash ID 0xc22014; NAND JEDEC 0x20762076)【26†L122-L130】.  It uses “dual‑flash” mode (SPI + NAND).
- **Partition map:** The bootloader firmware includes a fixed partition table (see §3 below).
- **Baudrate/Console:** The bootloader and Linux console both use 115200 bps 8N1 on the TTL header J305【24†L39-L41】【21†L25-L28】.  Hackaday logs confirm **two UART ports** on the board: one for the bootloader (console after reset) and one connected to Linux `/dev/ttyS0`【21†L25-L28】.  The bootloader console (bootloader messages and a `CM>` prompt) appears on reset.  Linux’s console comes up later on a second UART pair.
- **Recovery:** The bootloader supports loading images via TFTP or XMODEM (typical for Broadcom boards) if interrupted (the build notes say “linux.sto” can be TFTP-flashed【61†L0-L4】).  An unlocked serial console or bootloader prompt can write to flash (via a debug command `write -` etc.).  The `bcm2dump` utility supports the TC7200 profile and can communicate over serial to dump or write flash【67†L531-L539】.
- **Telnet:** Broadcom modems run a “BFC Telnet Server” (as noted by an exploit writeup) that listens on a management IP (192.168.100.1 by default).  On this internal interface, one can telnet in with configured credentials (often not set by default)【22†L125-L133】.  By default remote shell is disabled; a user obtained root by enabling it in the NVRAM config.  The `bcm2dump` tool can also use a telnet “CM>” interface to dump flash as shown below【67†L531-L539】. 

**Boot Log Excerpt:** The bootloader console shows (via Hackaday/wiki) similar output to a typical Broadcom gateway:

```
BCM3383A2, MemSize: 128 M, Chip ID: BCM3383Z-B0
BootLoader Version: 2.4.0alpha18p1 ... dual-flash reduced DDR
Build Date: Aug 14 2012 ...
SPI flash: 1MB (64KB blocks)
NAND flash: 64 MB (16KB blocks, 512B pages)
InitBoard: MIPS frequency 637200000
```

From this, the MIPS clock is ~637 MHz【26†L122-L130】.  The bootloader log also shows what partitions it will use (at 0x8000xxxx and 0x0000xxxx)【26†L127-L135】, as summarized in the next section.

**Serial/Pinout Table (J305):**

| Pin | Signal | Notes          |
|-----|--------|----------------|
| 1   | 3.3 V  | Power (only output; do not drive) |
| 2   | TX     | Bootloader/Linux console (UART transmit) |
| 3   | GND    | Ground         |
| 4   | RX     | Bootloader/Linux console (UART receive) |

Pin numbering is as shown on WikiDevi【24†L39-L41】 (stars mark Pin 1).  On TC7300 pictures, the 4-pin header is labeled J305; the TX/RX ordering may vary but 2 and 4 are the data lines.  Interface is 3.3 V TTL; many users solder jumper wires to the PCB or use a Tag-Connect adapter.

## 3. Flash Layout and Partitions

The TC7200 uses a **dual‑flash** layout: a small SPI NOR for boot parameters/NVRAM and a 64 MiB NAND for Linux/kernel/images.  The known partitioning (from the bootloader and `bcm2dump` profile【26†L122-L130】【67†L522-L530】) is:

- **RAM (DDR, 128 MiB):** Mapped at 0x8000_0000–0x87FF_FFFF.
- **SPI NVRAM (1 MiB total):** at 0x0000_0000–0x000F_FFFF (read-only from Linux’s view). It contains:
  - **bootloader:** 0x0000_0000–0x0000_FFFF (64 KiB) – first stage flash.
  - **permnv:**   0x0001_0000–0x0001_FFFF (64 KiB) – non-volatile kernel arguments.
  - **dynnv:**    0x0002_0000–0x000F_FFFF (896 KiB) – dynamic config (WAN MACs, settings).
  (The *GatewaySettings.bin* web config and broadcom BFC environment lives here.)
- **NAND Flash (64 MiB, at 0x0000_0000–0x03FF_FFFF):** Used for the rootfs and firmware images:
  - **linuxapps:** 0x0000_0000–0x019B_FFFF (26,368 KiB) – JFFS2 or squashfs for web UI and utilities.
  - **image1:**    0x019C_0000–0x0207_FFFF (6,912 KiB) – Primary Linux kernel image.
  - **image2:**    0x0208_0000–0x0273_FFFF (6,912 KiB) – Secondary (backup) kernel image.
  - **linux:**     0x0274_0000–0x02BB_FFFF (4,608 KiB) – Likely a RAMDisk or second kernel (appears redundant).
  - **linuxkfs:**  0x02BC_0000–0x03DB_FFFF (18,432 KiB) – Kernel filesystem (rootfs, root SquashFS or UBIFS).
  - **dhtml:**     0x03DC_0000–0x03FF_FFFF (2,304 KiB) – Static web UI files (HTML/DHTML pages).
  
These partitions match **Broadcom BFC convention**: two kernel slots (image1/image2) and a separate filesystem.  The active image is chosen by flags in NVRAM (which “image” to boot) or by bootloader logic.  (Some Broadcom devices use image1/image2 toggle for fallback.) 

> *Table: NAND Flash Partitions (NVRAM=SPI, JFFS2/Squash on NAND)*【67†L522-L530】*:*  

| Partition  | Offset        | Size     | Usage                                  |
|------------|---------------|----------|----------------------------------------|
| linuxapps  | 0x00000000    | 26368KB  | Web UI, apps (JFFS2 or squashfs)      |
| image1     | 0x019C0000    |  6912KB  | Linux kernel image (primary)           |
| image2     | 0x02080000    |  6912KB  | Linux kernel image (backup)            |
| linux      | 0x02740000    |  4608KB  | (Unclear – possibly secondary kernel)  |
| linuxkfs   | 0x02BC0000    | 18432KB  | Linux filesystem (rootfs)              |
| dhtml      | 0x03DC0000    |  2304KB  | Static web interface files (HTML)      |

*(Offsets relative to NAND base; from bcm2dump profile)*【67†L522-L530】.

**Kernel Version:** The vendor’s **running OS is Linux (LxG)** for the networking layer, and a separate eCos core for DOCSIS.  The exact Linux kernel version isn’t published, but Technicolor released GPL sources (the “LxG” tree) for the TC72xx series【74†L291-L300】.  That source build uses a Broadcom MIPS toolchain (see below).  Users have also compiled Linux 4.10+ manually on this hardware (unofficial port).  For OpenWrt, one would create a new device tree (bcm63xx) and cross-compile a kernel (likely a 4.x MIPS kernel) using the OpenWrt SDK/toolchain.

## 4. Vendor Firmware and Extraction

Technicolor firmware versions for the TC7200 use names like **TC7200-CF** or **TC7200-ST**.  Examples reported by users include versions **STD6.02.11** (circa 2012) and **TC7200-CF.01.20** or **TC7200-CF0144**【62†L53-L61】【62†L87-L93】.  (“.CF” builds appear on UPC/Belgacom units, “STDD” on German) – see the Docsis forum snippets above.  These images are typically loaded by cable ISPs, not user-downloadable.  However, one can extract them:

- **NVRAM/Config:** The web GUI allows downloading *GatewaySettings.bin* (the encrypted config). Tools like *bcm2cfg* or even simple scripts (see Exploit-DB) can decrypt it (default key is 0x00…0x1F) to view admin credentials【22†L67-L75】【70†L170-L179】.
- **Kernel/RootFS:** The NAND images can be dumped via the serial console or telnet using Broadcom debug protocols.  The [jclehner/bcm2-utils](https://github.com/jclehner/bcm2-utils) tool recognizes “tc7200” and can dump any partition over a serial or TCP connection【67†L531-L539】.  For example:  
  ```
  bcm2dump dump 192.168.100.1,admin,admin flash image1 image1.bin
  ``` 
  (requires enabling a telnet shell)【67†L531-L539】.  Alternatively, bootloader’s `memdump` can read RAM to get kernel in memory.  The TC7200’s OpenWrt port author used these methods to obtain stock Linux binaries.  

- **Extraction Steps:** In practice, one would open the case, wire up the UART, and use a host PC with `bcm2dump` or simple XMODEM/TFTP transfers.  The SparkFun tutorial “cold-boot attack” (dumping RAM on reset) is another approach if bootloader access is locked.  Hackaday logs describe dumping the first megabyte of RAM after reset to grab the boot sequence【21†L42-L50】.  Once dumps are obtained, one can analyze file systems (JFFS2/UBI images) or split the kernel/app partitions.  The vendor’s GitHub instructions【74†L291-L300】 explain building these images from source.

## 5. OpenWrt Support and Community Efforts

**Official Status:** *None.*  The TC7200/3383 is not supported by any official OpenWrt release.  OpenWrt’s Broadcom (bcm63xx/33xx) targets currently cover very few DOCSIS chips (e.g. CG3100D).  The TC7200’s combination of NAND, eCos modem, and Broadcom Wi‑Fi means it sits outside OpenWrt’s supported devices.  OpenWrt’s wiki and device tables mark most BCM33xx devices as *unsupported*【37†L13-L19】.  

**Patches/Ports:** A few community projects exist:
- **Linux Kernel Port:** User *jclehner* posted a Linux 4.x kernel tree for the TC7200 (see GitHub *linux-technicolor-tc7200*) and scripts for building it.  This custom build boots on TC7200 hardware, but it is *not* integrated into OpenWrt【61†L0-L4】.  It reveals how to drive the board’s hardware with Linux and may provide device tree examples.
- **Broadcom Utilities:** The `bcm2dump` and `bcm2cfg` tools (by the same author) explicitly support TC7200 (profile “tc7200”)【67†L531-L539】.  These are not OpenWrt, but they facilitate extracting and modifying firmware/config.  They require Python and can run on Linux or Windows to interact over serial or telnet.
- **Forums/Threads:** OpenWrt forums have a few threads discussing TC7200 in passing (e.g. IPv6 issues when used behind TC7200【36†L0-L4】).  There was a “sponsor porting” plea on OpenWrt forum (2012) but no follow-up solution.  On Hackaday, *rawe* documented hardware hacking (UART console, bootloader)【21†L25-L33】.  The Docsis.org forum shows user-shared firmware names and confirms dual-band capability【62†L74-L79】【62†L162-L164】.  Overall, knowledge is scattered.

**Build Instructions:**  To build OpenWrt for TC7200, one would use the OpenWrt build system (Cross GCC 4.x for MIPS24Kc).  However, since no official target exists, it likely requires:
- Adding a new board in `target/linux/bcm53xx/` with appropriate DTS and partition definitions.
- Possibly reusing Broadcom `bcm63xx` common code (NAND/Ethernet drivers). 
- Including Broadcom proprietary drivers (like `kmod-brcmfmac` for Wi-Fi) if licensing permits (these often need binary blobs).
- Building with the Broadcom toolchain (the vendor’s *toolchains.tar.gz*【74†L293-L300】 contains a cross-compiler compatible with LxG builds).
- For kernel patches, one might start from OpenWrt’s `bcm63xx` target and port the TC7200 specifics.  The vendor’s OpenSource zip includes a sample DTS for similar chips (BCM3384), which could be adapted.
  
**Dependencies:**  The vendor build uses GCC 4.9 (per recent Broadcom kernels) and requires standard Linux build tools.  OpenWrt uses a built-in musl toolchain (though early Broadcom support often used uClibc).  One must install `make`, `gcc`, `perl`, etc., and the Broadcom toolchain if building vendor images.  

## 6. Risks and Legal/Compatibility Issues

- **Proprietary Code:** The BCM3383’s DOCSIS engine is eCos-based and closed.  Any attempt to enable cable modem functionality under Linux would require proprietary drivers and firmware (not available under GPL).  In practice, an OpenWrt port would likely *disable the cable modem*, using the device as a router/AP only.
- **Wireless Driver:** The onboard Wi-Fi (BCM43227) typically requires a Broadcom binary driver (brcmfmac), which is GPL-incompatible or unavailable open.  OpenWrt might not support it fully; as a fallback one might disable Wi-Fi or replace with an external AP.
- **Certification/Regulations:** The TC7200 is FCC/CE certified as a cable gateway.  Flashing new firmware that alters its radio or cable behavior could technically void compliance.  Using it without proper ISP provisioning may violate DOCSIS security rules.  (However, for pure router use in a lab or behind a proper cable modem, this is low risk.)
- **Warranty/Brick:** Mistakes in flashing can brick the device (mis-flashed bootloader or wrong partitions).  Having serial access mitigates this, but caution is needed.
- **GPL Compliance:** Technicolor did release GPL source for most Linux components.  Using that code requires observing their GPL license (attribution, not merging proprietary blobs).  Conversely, any use of Broadcom proprietary parts could pose license conflicts.
- **Compatibility:** Even with successful build, some hardware (e.g. voice ports, DOCSIS) would remain unusable.  The port’s value is mainly in Wi-Fi/LAN routing.  Performance tuning (e.g. interrupt migration on MIPS, hardware NAT) would need work.

## 7. Recommended Porting Steps

1. **Set up Serial Console:** Connect to J305 with a USB-TTL adapter (115200 8N1).  Verify bootloader messages on power cycle【21†L25-L33】.
2. **Dump Existing Firmware:** Use `bcm2dump` or bootloader to dump partitions (e.g. `bcm2dump dump /dev/ttyUSB0 flash image1 image1.bin`)【67†L531-L539】.  Save `linuxapps`, `linuxkfs`, etc. for analysis.
3. **Analyze Filesystems:** Identify rootfs type (JFFS2/UBI) and unpack as needed.  Examine `version.txt` or kernel strings to guess build environment.
4. **Obtain Vendor Sources:** Clone Technicolor’s TC72xx OpenSource repo (or vendor SDK)【74†L291-L300】.  Extract the toolchain (`toolchains.tar.gz`) and reference DTS (if any) for BCM338x.
5. **Set Up Toolchain:** Either use OpenWrt’s MIPS toolchain or the vendor’s Broadcom compiler.  Ensure `gcc` supports MIPS24K and is ~4.9.x.
6. **Develop DTS/Board File:** Create a device tree or board file for “tc7200” based on BCM3383.  Use the kernel’s `bcm63xx-generic` as a start.  Define memory (128MB), peripherals (Ethernet switch, NAND, SPI, PCIe slot, LEDs, UART).  The vendor code may have a sample DTS for BCM3384 (TC7230)【74†L300-L308】.
7. **Kernel and Rootfs:** Configure kernel to enable NAND, switch, etc.  Integrate any necessary broadcom drivers.  Build a minimal Linux kernel and rootfs (likely as ext4 or squashfs).
8. **Flashing:** Use bootloader’s TFTP or `bcm2dump write` to flash the new kernel and rootfs into the `image1`/`image2` or `linuxkfs` partitions.  For example, `bcm2dump write /dev/ttyUSB0 flash image1 newkernel.bin`.
9. **Test and Iterate:** Boot the new image (watch serial console).  If kernel panics, adjust DTS or driver config.  Use a fallback image if possible.
10. **Finalize:** Once stable, merge into an OpenWrt build system.  Document the porting steps for others.

```mermaid
flowchart TD
    A[Start: TC7200 H/W] --> B[Connect UART console]
    B --> C[Dump stock flash (bcm2dump)]
    C --> D[Analyze partitions/files]
    D --> E[Set up cross-compiler & build env]
    E --> F[Write DTS/patch kernel]
    F --> G[Compile kernel + rootfs]
    G --> H[Flash new firmware (bootloader/TFTP)]
    H --> I[Test boot & fix issues]
    I --> J[Success: OpenWrt runs on TC7200]
```

```mermaid
flowchart LR
    subgraph PowerOn
        Bootrom-->Bootloader
    end
    Bootloader{"Bootloader (v2.4.0α18p1)"} --> Select{"Select image"}
    Select --> |Primary| Kernel1[Image1: Linux kernel]
    Select --> |Backup| Kernel2[Image2: Linux kernel]
    Kernel1 --> Rootfs[Root FS (linuxkfs)]
    Kernel2 --> Rootfs
    Rootfs --> Applications[apps (linuxapps)]
    Applications --> BootComplete[System init completes]
```

## 8. Tables of Variants and Sources

| **Model/Variant** | **Wifi**           | **Voice (EMTA)** | **Firmware Prefix** | **Notes/Detection**                                                     |
|-------------------|--------------------|------------------|---------------------|-------------------------------------------------------------------------|
| TC7200 (base)     | Dual-band (2.4/5)  | Yes              | TC7200-CF, STD*     | Common unbranded; PCB same as TC7230; FCC IDs H8N-TC7200, PKE1331BP【24†L29-L35】.  Check label or FCC ID. |
| TC7200.U          | Dual-band          | Yes              | TC7200.U (UPC logos) | UPC-branded; likely runs same stock but locked UI.                       |
| TC7200.20         | Single radio (2.4/5 selectable) | Yes  | TC7200.20-STDD*    | Lower-end model (no dual concurrent); UI restricts band selection【62†L53-L61】. |
| TC7200.d          | Dual-band          | No (EMTA disabled) | TC7200.d-ST**      | No voice support; marketed as data-only EMTA removal variant.           |
| TC7300            | Single-band (2.4)  | Yes              | TC7300-CF, ST**    | Similar board without USB and on/off; FCC ID H8N-TC7300【26†L197-L203】. |

*Firmware codes beginning “CF” or “STCE/STD” vary by provider; newer firmwares e.g. TC7200-CF0144 (late 2015) have “eCos_linux-E” suffix【62†L162-L164】.  The “.ST**” codes often denote special builds (e.g. TC7200.20 uses STD/STDD)【62†L72-L79】【62†L162-L164】.  

| **Source Type**           | **Examples**                                    | **Coverage/Notes**                      |
|---------------------------|-------------------------------------------------|-----------------------------------------|
| FCC/Test Docs             | FCC ID H8N-PKE1331BP filings                    | Hardware images, block diagrams         |
| Tech Docs/User Manuals    | TC7200 datasheets (e.g. 2012 specs PDF)         | Confirms CPU, DOCSIS, features          |
| WikiDevi/TechinfoDepot【24†L29-L35】 | Summarized hardware (BCM3383 SoC, RAM, flash) | Excellent spec summary                 |
| Hackaday/DIY Logs【21†L25-L33】 | UART pinout, bootloader version              | User teardown, exploitable info         |
| Exploit-DB【70†L70-L79】        | Firmware bug writeup (e.g. STD6.02.11)        | Names vendor version; warns about backup |
| OpenWrt Forums / RSS/Lists | Threads on TC7200, sponsor request; OpenWrt-devel posting【72†L19-L27】 | Community status (mostly negative)      |
| GitHub - tch-opensrc【74†L291-L300】   | Technicolor GPL sources for TC72XX           | Build scripts, kernel/rootfs sources    |
| GitHub - jclehner/linux-tech...【61†L0-L4】 | Custom Linux port for TC7200               | Not official; shows kernel work        |
| bcm2-utils【67†L531-L539】         | Tools for Broadcom modems (profile “tc7200”) | Extract/dump firmware/config            |

These sources (FCC and vendor data via TechInfoDepot/WikiDevi【24†L29-L35】, community logs) confirm the hardware and boot details.  We rely on them for specs and partition layouts【26†L122-L130】【67†L531-L539】.  Where official vendor info is lacking (e.g. DTS), community efforts fill gaps (bcm2-utils, GitHub port). 

