//@category TC7200
//
// Apply reverse-engineering labels for TC7200 stage1 images.
// Works without PyGhidra (Java script).

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;

public class tc7200_stage1_label_map extends GhidraScript {

	private static final boolean CREATE_FUNCTIONS = false;
	private static final String DEFAULT_PROFILE = "d60242";
	private static final String EXPECTED_LANGUAGE_ID = "MIPS:BE:32:default";

	private static final class LabelDef {
		final long addr;
		final String name;
		final String comment;

		LabelDef(long addr, String name, String comment) {
			this.addr = addr;
			this.name = name;
			this.comment = comment;
		}
	}

	private static final class ObsoleteLabelDef {
		final long addr;
		final String name;

		ObsoleteLabelDef(long addr, String name) {
			this.addr = addr;
			this.name = name;
		}
	}

	private final Map<String, List<LabelDef>> profileLabels = new HashMap<>();
	private final Map<String, List<ObsoleteLabelDef>> obsoleteProfileLabels = new HashMap<>();

	@Override
	protected void run() throws Exception {
		String lang = currentProgram.getLanguageID().getIdAsString();
		if (!EXPECTED_LANGUAGE_ID.equals(lang)) {
			printerr("Wrong language: " + lang);
			printerr("Expected exact language: " + EXPECTED_LANGUAGE_ID + ".");
			printerr("This stage1 image is MIPS32, not MIPS16 or little-endian MIPS.");
			printerr("Re-import as Raw Binary with MIPS default / 32 / big / default.");
			return;
		}

		initProfiles();
		List<String> profiles = Arrays.asList("d60242", "dc0103");
		String profile = askChoice("TC7200 Label Map", "Select profile", profiles, DEFAULT_PROFILE);
		List<LabelDef> labels = profileLabels.get(profile);
		if (labels == null) {
			printerr("Unknown profile: " + profile);
			return;
		}
		removeObsoleteLabels(profile);

		int applied = 0;
		for (LabelDef def : labels) {
			applyLabel(def);
			applied++;
		}
		println("Applied " + applied + " labels for profile '" + profile + "'.");
	}

	private void applyLabel(LabelDef def) {
		Address addr = toAddr(def.addr);
		try {
			if (!hasLabelAtAddress(addr, def.name)) {
				createLabel(addr, def.name, true, SourceType.USER_DEFINED);
			}
		}
		catch (Exception e) {
			printerr("Label failed at " + addr + " for " + def.name + ": " + e.getMessage());
		}

		try {
			String existing = getPlateComment(addr);
			if ((existing == null || existing.isEmpty()) && def.comment != null && !def.comment.isEmpty()) {
				setPlateComment(addr, def.comment);
			}
		}
		catch (Exception e) {
			printerr("Comment failed at " + addr + " for " + def.name + ": " + e.getMessage());
		}

		if (CREATE_FUNCTIONS) {
			try {
				Function fn = getFunctionAt(addr);
				if (fn == null) {
					disassemble(addr);
					fn = createFunction(addr, def.name);
				}
				if (fn != null) {
					fn.setName(def.name, SourceType.USER_DEFINED);
				}
			}
			catch (Exception e) {
				printerr("Function rename/create failed at " + addr + " for " + def.name + ": " + e.getMessage());
			}
		}
	}

	private boolean hasLabelAtAddress(Address addr, String expectedName) {
		Symbol[] symbols = currentProgram.getSymbolTable().getSymbols(addr);
		for (Symbol s : symbols) {
			if (expectedName.equals(s.getName())) {
				return true;
			}
		}
		return false;
	}

	private void removeObsoleteLabels(String profile) {
		List<ObsoleteLabelDef> obsolete = obsoleteProfileLabels.get(profile);
		if (obsolete == null) {
			return;
		}
		for (ObsoleteLabelDef def : obsolete) {
			Address addr = toAddr(def.addr);
			try {
				Symbol[] symbols = currentProgram.getSymbolTable().getSymbols(addr);
				for (Symbol s : symbols) {
					if (def.name.equals(s.getName())) {
						s.delete();
					}
				}
			}
			catch (Exception e) {
				printerr("Obsolete-label cleanup failed at " + addr + " for " + def.name + ": " + e.getMessage());
			}
		}
	}

	private void initProfiles() {
		List<LabelDef> d60242 = new ArrayList<>();
		d60242.add(new LabelDef(0x80004000L, "entry_stage1_reset_vector", "Stage1 reset/entry window with early CP0/watch register initialization; keep this region in MIPS32 mode."));
		d60242.add(new LabelDef(0x803F6D90L, "fn_nandflashread_with_replacement", "NAND read path with replacement-block handling."));
		d60242.add(new LabelDef(0x803F6DA0L, "loc_nandflashread_prologue_tail", "Late prologue body / secondary entry region."));
		d60242.add(new LabelDef(0x803F6E14L, "xref_log_nand_no_replacement", "Logs replacement-block failure."));
		d60242.add(new LabelDef(0x803F6F3CL, "loc_nand_out_of_order_compare", "Checks tagged NAND block state against the expected offset."));
		d60242.add(new LabelDef(0x803F6F40L, "xref_log_nand_out_of_order", "Logs out-of-order NAND block metadata."));
		d60242.add(new LabelDef(0x803F6F64L, "loc_nand_replacement_missing_branch", "Resolver returned 0; branch to the hard failure path."));
		d60242.add(new LabelDef(0x803F6F70L, "xref_log_nand_replacement_found", "Logs the replacement block chosen for an out-of-order NAND read."));
		d60242.add(new LabelDef(0x803F70D0L, "loc_nand_success_return", "Normal success return path with v0=0."));
		d60242.add(new LabelDef(0x803FACACL, "fn_find_replacement_block_candidate", "Resolver for out-of-order NAND block metadata; returns a replacement candidate or 0."));
		d60242.add(new LabelDef(0x810746CCL, "str_nand_no_replacement", "NandFlashRead: Failed to find replacement block!"));
		d60242.add(new LabelDef(0x81074738L, "str_nand_out_of_order", "NandFlashRead: Detected out-of-order block..."));
		d60242.add(new LabelDef(0x8107479CL, "str_nand_replacement_found", "NandFlashRead: Found replacement block at 0x%s"));
		d60242.add(new LabelDef(0x801CD700L, "fn_docsis_ctl_create_helper", "DOCSIS control thread creation helper window."));
		d60242.add(new LabelDef(0x801CD780L, "xref_docsis_ctl_create_log", "Xref to Creating DOCSIS Control Thread... string."));
		d60242.add(new LabelDef(0x801CD7F0L, "fn_docsis_ctl_init_main", "DOCSIS control initialization main window."));
		d60242.add(new LabelDef(0x801CF1CCL, "xref_docsis_ctl_command_table", "Xref to CM DOCSIS Control Thread Commands string."));
		d60242.add(new LabelDef(0x80FE9278L, "str_docsis_ctl_create", "Creating DOCSIS Control Thread..."));
		d60242.add(new LabelDef(0x80FE9D00L, "str_docsis_ctl_commands", "CM DOCSIS Control Thread Commands"));
		d60242.add(new LabelDef(0x800DC5C0L, "fn_tr69_thread_init", "TR-069 thread init window."));
		d60242.add(new LabelDef(0x800DC63CL, "xref_tr69_create_log", "Xref to Creating TR-069 Thread... string."));
		d60242.add(new LabelDef(0x80FB38FCL, "str_tr69_create", "Creating TR-069 Thread..."));
		d60242.add(new LabelDef(0x8049714CL, "fn_tp_handshake_flow", "TP handshake flow with init/reply/unexpected logging."));
		d60242.add(new LabelDef(0x80497180L, "loc_tp_handshake_setup", "Handshake context base/index setup block."));
		d60242.add(new LabelDef(0x804971E8L, "xref_tp_handshake_init", "Xref to initial handshake format string."));
		d60242.add(new LabelDef(0x8049720CL, "loc_tp_handshake_post_first_rx", "Post-first-RX branch point before entering the persistent TP handshake loop."));
		d60242.add(new LabelDef(0x80497220L, "xref_tp_handshake_first_message_event", "Xref to the first-message event log in the TP handshake flow."));
		d60242.add(new LabelDef(0x80497230L, "xref_tp_getmsg_handshake_err", "Xref to the getHostDqmMessage(handshake) error log."));
		d60242.add(new LabelDef(0x804972B0L, "xref_tp_handshake_reply_log", "Xref to reply-handshake format string."));
		d60242.add(new LabelDef(0x804972D0L, "xref_tp_handshake_unexpected", "Xref to handshake unexpected-message string."));
		d60242.add(new LabelDef(0x804972E0L, "loc_tp_handshake_main_loop", "Main infinite TP RX/dispatch loop after handshake setup."));
		d60242.add(new LabelDef(0x8049731CL, "loc_tp_handshake_window_end", "Late block in the observed handshake-supporting code window."));
		d60242.add(new LabelDef(0x804C8F60L, "fn_tp_unexpected_message_logger", "Logs unexpected TP/DQM messages."));
		d60242.add(new LabelDef(0x804C8F6CL, "xref_tp_unexpected_message_fmt", "Xref to '%s unexpected message %08lx'."));
		d60242.add(new LabelDef(0x804C91BCL, "fn_tp_message_dispatch", "TP message parsing/dispatch window."));
		d60242.add(new LabelDef(0x803E64F8L, "fn_scan_boot_entries_for_linuxkfs", "Scans a boot-entry table for the linuxkfs name using the shared memcmp helper."));
		d60242.add(new LabelDef(0x804C8DECL, "fn_bootlinux_init_slot1_once", "One-time BootLinux init wrapper for slot/context 1; guards a flag, initializes state, then registers an 8-byte block via FUN_80497110."));
		d60242.add(new LabelDef(0x80481F88L, "fn_build_ssdp_discovery_response", "Shared SSDP discovery-response builder used from the broader BootLinux path."));
		d60242.add(new LabelDef(0x80481FC8L, "fn_build_ssdp_discovery_response_core", "Core/tail portion of the SSDP discovery-response builder."));
		d60242.add(new LabelDef(0x804C99D0L, "fn_boot_linux_entry", "Top-level BootLinux coordinator: emits the TP1 boot log, runs the boot gate, performs once-only init paths, adjusts boot-entry bounds, scans for linuxkfs, then enters the final boot transition."));
		d60242.add(new LabelDef(0x804C9A58L, "loc_boot_linux_allowed", "BootLinux branch reached after the gate/check path allows Linux boot."));
		d60242.add(new LabelDef(0x804C9B40L, "loc_boot_linux_args_setup", "BootLinux boot-args formatting/logging window that precedes the handoff copy loop."));
		d60242.add(new LabelDef(0x804C9B80L, "xref_linux_boot_args_log", "Xref to Linux Boot Args string."));
		d60242.add(new LabelDef(0x804C9B9CL, "loc_boot_linux_handoff_copy_loop", "Copies the prepared handoff structure into the 0x87000000 region."));
		d60242.add(new LabelDef(0x804C9BD0L, "loc_post_handoff_stage", "Post-copy handoff stage before BootLinux returns success."));
		d60242.add(new LabelDef(0x804C9BD8L, "loc_boot_linux_return_success", "Success return path for BootLinux with v0=1."));
		d60242.add(new LabelDef(0x804C9BDCL, "loc_boot_linux_epilogue", "Shared BootLinux epilogue restoring registers and returning."));
		d60242.add(new LabelDef(0x80E9D958L, "fn_snprintf", "Small printf-style wrapper used by the boot-argument builder and related logging paths."));
		d60242.add(new LabelDef(0x80E9DD64L, "fn_vfprintf_core", "Core varargs formatting engine behind the boot/log printf wrappers."));
		d60242.add(new LabelDef(0x80E9FFB0L, "fn_memcmp", "memcmp implementation with aligned 32-bit fast path and byte-by-byte fallback."));
		d60242.add(new LabelDef(0x80681AB8L, "fn_bootlinux_init_slot2_once", "One-time BootLinux init wrapper for slot/context 2; guards a flag, initializes state, then registers a 10-byte block via FUN_80497110."));
		d60242.add(new LabelDef(0x80FC9CB8L, "str_booting_linux_tp1", "Booting Linux on TP1..."));
		d60242.add(new LabelDef(0x810A8E80L, "str_linux_boot_args", "Linux Boot Args: %s"));
		d60242.add(new LabelDef(0x810A074CL, "str_tp_handshake_init_fmt", "<<<<< %s sent initial handshake >>>>>>"));
		d60242.add(new LabelDef(0x810A07A0L, "str_tp_getmsg_handshake_err", "Error: getHostDqmMessage(handshake) on %s"));
		d60242.add(new LabelDef(0x810A07CCL, "str_tp_handshake_unexpected_err", "Error: handshake rx unexpected message"));
		d60242.add(new LabelDef(0x810A07F4L, "str_tp_handshake_reply_fmt", "<<<<< %s sent reply handshake message >>>>>>"));
		d60242.add(new LabelDef(0x810A0A2CL, "str_tp_init_service_handshake", "init_service_handshake"));
		d60242.add(new LabelDef(0x810A8AFCL, "str_tp_unexpected_fmt_hex", "%s unexpected message %08lx"));
		d60242.add(new LabelDef(0x810A8B9CL, "str_tp_unexpected_fmt_dec", "%s: unexpected message %d"));
		d60242.add(new LabelDef(0x8138410CL, "str_tp_secondary_app_initialized", "Thread processor handshake. Secondary app initialized properly."));
		d60242.add(new LabelDef(0x81064BF4L, "str_enet_cfg_gmac_core_phy_hex", "Enet Config GMAC UNIMAC Core: 0x%x Phy: 0x%x"));
		d60242.add(new LabelDef(0x81064C25L, "str_enet_starting_gmac_init", "Enet Starting GMAC Init..!"));
		d60242.add(new LabelDef(0x81065095L, "str_enet_starting_unimac_mbdma_phy_init", "Starting Enet UNIMAC/MBDMA/PHY Init..!"));
		d60242.add(new LabelDef(0x810650C0L, "str_enet_unimac_core", "Enet UNIMAC Core: 0x%x"));
		d60242.add(new LabelDef(0x810650D8L, "str_enet_unimac_iface_interrupts", "Enet UNIMAC Iface Interrupts: 0x%x"));
		d60242.add(new LabelDef(0x810650FCL, "str_enet_gmac_core_cmd", "GMAC Core Cmd: 0x%x"));
		d60242.add(new LabelDef(0x81065114L, "str_enet_gmac_speed", "GMAC Speed: 0x%x"));
		d60242.add(new LabelDef(0x81065128L, "str_enet_switch_power_up_pin", "Powering UP switch. PIN = %d"));
		d60242.add(new LabelDef(0x81065148L, "str_enet_switch_power_down_pin", "Powering DOWN switch. PIN = %d"));
		d60242.add(new LabelDef(0x81065168L, "str_enet_cfg_gmac_core_phy_dec", "Enet Config GMAC UNIMAC Core: %d Phy: %d"));
		d60242.add(new LabelDef(0x8106544CL, "str_enet_probe_mac_phy_id_timeout", "Probing mac %d, phy %d, id %x, timeout %d"));
		d60242.add(new LabelDef(0x81065478L, "str_enet_found_phy_mdio_mac", "Found PHY %d, MDIO on MAC %d"));
		d60242.add(new LabelDef(0x810655E4L, "str_ethernet_command_table", "Ethernet Command Table"));
		d60242.add(new LabelDef(0x81065658L, "str_mii_reading_register", "Reading MII register..."));
		d60242.add(new LabelDef(0x810656A0L, "str_mii_writing_register", "Writing MII register..."));
		d60242.add(new LabelDef(0x80FC7454L, "str_avs_thread_constructor", "AVS Thread Constructor...."));
		d60242.add(new LabelDef(0x80FC7E44L, "str_avs_reboot_margin_change", "Rebooting system to affect AVS margin change"));
		d60242.add(new LabelDef(0x80FCD670L, "str_programstore_header_hcs_failed_expected", "ProgramStore header HCS failed!  Expected "));
		d60242.add(new LabelDef(0x80FCD69CL, "str_programstore_header_signature_incorrect", "ProgramStore header Signature incorrect!  Found "));
		d60242.add(new LabelDef(0x80FCD714L, "str_programstore_header_control_incorrect", "ProgramStore header Control incorrect!  Image must not be compressed!"));
		d60242.add(new LabelDef(0x81055B2CL, "str_create_emta_command_table", "Creating BcmEmtaCommandTable"));
		d60242.add(new LabelDef(0x81056234L, "str_create_emta_endpt_command_table", "Creating BcmEmtaEndptCommandTable"));
		d60242.add(new LabelDef(0x810D3A38L, "str_programstore_driver_init", "ProgramStoreDriverInit"));
		d60242.add(new LabelDef(0x810D3D88L, "str_programstore_driver_is_header_valid", "ProgramStoreDriverIsHeaderValid"));
		d60242.add(new LabelDef(0x810D3F34L, "str_combined_programstore_driver_is_header_valid", "CombinedProgramStoreDriverIsHeaderValid"));
		d60242.add(new LabelDef(0x810D48F0L, "str_combined_programstore_header_verified", "Combined ProgramStore header was verified.  Image can be downloaded."));
		d60242.add(new LabelDef(0x810FC3CCL, "str_powering_on_usb", "Powering on USB"));
		d60242.add(new LabelDef(0x8116DBD0L, "str_create_host_fap_dqm_manager", "Creating a new host FAP DQM manager. Instance: %08x"));
		d60242.add(new LabelDef(0x8116DC70L, "str_create_host_msg_proc_dqm_manager", "Creating a new host MSG PROC DQM manager. Instance: %08x, DQM_REGS = %08x, CTRL_REGS = %08x"));
		d60242.add(new LabelDef(0x8116DCD4L, "str_create_host_pmc_dqm_manager", "Creating a new host PMC DQM manager. Instance: %08x, DQM_REGS = %08x, CTRL_REGS = %08x"));
		d60242.add(new LabelDef(0x803A2D94L, "fn_enet_snmp_register_handlers", "SNMP-related registration flow used by Ethernet init sequence."));
		d60242.add(new LabelDef(0x803A2F10L, "loc_enet_snmp_register_stage", "Internal stage inside SNMP registration flow (not a standalone function)."));
		d60242.add(new LabelDef(0x803A873CL, "fn_enet_gmac_init_step1", "Early GMAC init helper stage."));
		d60242.add(new LabelDef(0x803A8B30L, "fn_enet_gmac_init_step2", "GMAC core command bit staging by board profile and interface."));
		d60242.add(new LabelDef(0x803A8C10L, "fn_enet_gmac_init_core", "Core GMAC register init helper invoked from step1."));
		d60242.add(new LabelDef(0x803AE840L, "fn_enet_gmac_init_step6", "Main UNIMAC/MBDMA/PHY init stage with final command programming."));
		d60242.add(new LabelDef(0x803AED40L, "fn_enet_poll_or_wait_ready", "Wait/poll helper used by GMAC init step6."));
		d60242.add(new LabelDef(0x803AEFECL, "fn_enet_build_core_cmd", "Builds GMAC command and speed/duplex selection from PHY type and link mode."));
		d60242.add(new LabelDef(0x80FA1DD8L, "str_fpm_buffer_size_prefix", "Setting FPM Buffer size to: "));
		d60242.add(new LabelDef(0x81017BA8L, "str_cablemodem_agent", "cablemodem agent"));
		d60242.add(new LabelDef(0x810A8D5BL, "str_tp1_function_tag_fmt", "P%s() TP1"));
		d60242.add(new LabelDef(0x810A0E5CL, "str_restartlinux_not_supported_tp1", "RestartLinux not supported for BFC_LINUX_ON_TP1"));
		d60242.add(new LabelDef(0x810CC42CL, "str_pci_core_init", "PCI Core Init!  instance = %d, pCoreRegs = %08x"));
		d60242.add(new LabelDef(0x810CC4C8L, "str_pci_core_no_link_status", "PCI Core Init Instance (%d): No Link Status Found! Skipping enumeration."));
		d60242.add(new LabelDef(0x810CC514L, "str_pci_core_link_up", "PCI Core Init: Link is UP!"));
		d60242.add(new LabelDef(0x8138428CL, "str_tp1_itpc_reset_cmd", "ResetThreadProcessor: TP1 has received ITPC_RESET_CMD command"));
		profileLabels.put("d60242", d60242);

		List<LabelDef> dc0103 = new ArrayList<>();
		dc0103.add(new LabelDef(0x80004000L, "entry_stage1_reset_vector", "Stage1 reset/entry window with early CP0/watch register initialization; keep this region in MIPS32 mode."));
		dc0103.add(new LabelDef(0x8039AA30L, "fn_nandflashread_with_replacement", "NAND read path with replacement-block handling."));
		dc0103.add(new LabelDef(0x8039A950L, "fn_find_replacement_block_candidate", "Scans replacement-block metadata and returns a candidate block or 0."));
		dc0103.add(new LabelDef(0x8039AA40L, "loc_nandflashread_prologue_tail", "Late prologue body / secondary entry region."));
		dc0103.add(new LabelDef(0x8039AAB4L, "xref_log_nand_no_replacement", "Logs replacement-block failure."));
		dc0103.add(new LabelDef(0x8039AB8CL, "xref_log_nand_out_of_order", "Logs out-of-order NAND block metadata."));
		dc0103.add(new LabelDef(0x80EA46ACL, "str_nand_no_replacement", "NandFlashRead: Failed to find replacement block!"));
		dc0103.add(new LabelDef(0x80EA46E0L, "str_nand_out_of_order", "NandFlashRead: Detected out-of-order block..."));
		dc0103.add(new LabelDef(0x8018C100L, "fn_docsis_ctl_create_helper", "DOCSIS control thread creation helper window."));
		dc0103.add(new LabelDef(0x8018C1B8L, "fn_docsis_ctl_init_main", "DOCSIS control initialization main window."));
		dc0103.add(new LabelDef(0x8018DB90L, "xref_docsis_ctl_command_table", "Xref to CM DOCSIS Control Thread Commands string."));
		dc0103.add(new LabelDef(0x80E1F220L, "str_docsis_ctl_create", "Creating DOCSIS Control Thread..."));
		dc0103.add(new LabelDef(0x80E1FB58L, "str_docsis_ctl_commands", "CM DOCSIS Control Thread Commands"));
		dc0103.add(new LabelDef(0x800AA620L, "fn_tr69_thread_init", "TR-069 thread init window."));
		dc0103.add(new LabelDef(0x800AA69CL, "xref_tr69_create_log", "Xref to Creating TR-069 Thread... string."));
		dc0103.add(new LabelDef(0x80DEC260L, "str_tr69_create", "Creating TR-069 Thread..."));
		dc0103.add(new LabelDef(0x8046C1E4L, "fn_itc_hal_init_and_registration", "ITC HAL registration + queue setup window."));
		dc0103.add(new LabelDef(0x8046C1FCL, "xref_itc_hal_commands", "Xref to ITC HAL command-table string."));
		dc0103.add(new LabelDef(0x8046DE80L, "fn_boot_linux_handoff", "Linux handoff + boot args logging window."));
		dc0103.add(new LabelDef(0x8046DEA0L, "xref_linux_boot_args_log", "Xref to Linux Boot Args string."));
		dc0103.add(new LabelDef(0x80EE2464L, "str_linux_boot_args", "Linux Boot Args: %s"));
		dc0103.add(new LabelDef(0x80EE16E4L, "str_itc_hal_commands", "ITC HAL Commands"));
		dc0103.add(new LabelDef(0x80EE20FAL, "str_itc_initialized_banner", ">>> ITC Initialized!!! <<<"));
		profileLabels.put("dc0103", dc0103);

		List<ObsoleteLabelDef> d60242Obsolete = new ArrayList<>();
		d60242Obsolete.add(new ObsoleteLabelDef(0x803F6CACL, "fn_find_replacement_block_candidate"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x803EA4F8L, "fn_select_rootfs_boot_mode"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x803EA4F8L, "fn_detect_ubi_rootfs_boot_mode"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x803EA4F8L, "fn_parse_float_token"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x80481F88L, "fn_process_ssdp_discovery_packet"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x80481FC8L, "fn_process_ssdp_discovery_packet_core"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804C9B40L, "fn_boot_linux_handoff"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804C9BD0L, "loc_post_handoff_reconfigure_lease_pool"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804CCDECL, "fn_find_and_flag_matching_entry"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804CCF54L, "fn_lookup_matching_entry"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804CD9B8L, "fn_prepare_linux_handoff_context"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804CDEE0L, "fn_linux_handoff_stage2"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804CDEE0L, "fn_reconfigure_lease_pool_impl"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804CE210L, "fn_reconfigure_lease_pool_conflict_path"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804DF130L, "fn_copy_entry_record"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804CD840L, "fn_log_user_assertion_failed"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804CD840L, "fn_boot_args_helper"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x80497190L, "loc_tp_handshake_main_loop"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x804971E4L, "xref_tp_handshake_init"));
		d60242Obsolete.add(new ObsoleteLabelDef(0x8049720CL, "loc_tp_handshake_main_loop"));
		obsoleteProfileLabels.put("d60242", d60242Obsolete);
	}
}
