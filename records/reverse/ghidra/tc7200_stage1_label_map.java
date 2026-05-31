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

	private final Map<String, List<LabelDef>> profileLabels = new HashMap<>();

	@Override
	protected void run() throws Exception {
		String lang = currentProgram.getLanguageID().getIdAsString();
		if (lang.contains(":LE:")) {
			printerr("Wrong language: " + lang);
			printerr("Expected big-endian MIPS (MIPS:BE:32:default).");
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
		Symbol s = getSymbolAt(addr);
		return s != null && expectedName.equals(s.getName());
	}

	private void initProfiles() {
		List<LabelDef> d60242 = new ArrayList<>();
		d60242.add(new LabelDef(0x803F6D90L, "fn_nandflashread_with_replacement", "NAND read path with replacement-block handling."));
		d60242.add(new LabelDef(0x803F6CACL, "fn_find_replacement_block_candidate", "Scans replacement-block metadata and returns a candidate block or 0."));
		d60242.add(new LabelDef(0x803F6DA0L, "loc_nandflashread_prologue_tail", "Late prologue body / secondary entry region."));
		d60242.add(new LabelDef(0x803F6E14L, "xref_log_nand_no_replacement", "Logs replacement-block failure."));
		d60242.add(new LabelDef(0x803F6F40L, "xref_log_nand_out_of_order", "Logs out-of-order NAND block metadata."));
		d60242.add(new LabelDef(0x810746CCL, "str_nand_no_replacement", "NandFlashRead: Failed to find replacement block!"));
		d60242.add(new LabelDef(0x81074738L, "str_nand_out_of_order", "NandFlashRead: Detected out-of-order block..."));
		d60242.add(new LabelDef(0x801CD700L, "fn_docsis_ctl_create_helper", "DOCSIS control thread creation helper window."));
		d60242.add(new LabelDef(0x801CD7F0L, "fn_docsis_ctl_init_main", "DOCSIS control initialization main window."));
		d60242.add(new LabelDef(0x801CF1CCL, "xref_docsis_ctl_command_table", "Xref to CM DOCSIS Control Thread Commands string."));
		d60242.add(new LabelDef(0x80FE9278L, "str_docsis_ctl_create", "Creating DOCSIS Control Thread..."));
		d60242.add(new LabelDef(0x80FE9D00L, "str_docsis_ctl_commands", "CM DOCSIS Control Thread Commands"));
		d60242.add(new LabelDef(0x800DC5C0L, "fn_tr69_thread_init", "TR-069 thread init window."));
		d60242.add(new LabelDef(0x800DC63CL, "xref_tr69_create_log", "Xref to Creating TR-069 Thread... string."));
		d60242.add(new LabelDef(0x80FB38FCL, "str_tr69_create", "Creating TR-069 Thread..."));
		d60242.add(new LabelDef(0x8049714CL, "fn_tp_handshake_flow", "TP handshake flow with init/reply/unexpected logging."));
		d60242.add(new LabelDef(0x80497180L, "loc_tp_handshake_setup", "Handshake context base/index setup block."));
		d60242.add(new LabelDef(0x804971E4L, "xref_tp_handshake_init", "Xref to initial handshake format string."));
		d60242.add(new LabelDef(0x804972D0L, "xref_tp_handshake_unexpected", "Xref to handshake unexpected-message string."));
		d60242.add(new LabelDef(0x804C8F60L, "fn_tp_unexpected_message_logger", "Logs unexpected TP/DQM messages."));
		d60242.add(new LabelDef(0x804C8F6CL, "xref_tp_unexpected_message_fmt", "Xref to '%s unexpected message %08lx'."));
		d60242.add(new LabelDef(0x804C91BCL, "fn_tp_message_dispatch", "TP message parsing/dispatch window."));
		d60242.add(new LabelDef(0x804C9B40L, "fn_boot_linux_handoff", "Linux handoff + boot args logging window."));
		d60242.add(new LabelDef(0x804C9B80L, "xref_linux_boot_args_log", "Xref to Linux Boot Args string."));
		d60242.add(new LabelDef(0x80FC9CB8L, "str_booting_linux_tp1", "Booting Linux on TP1..."));
		d60242.add(new LabelDef(0x810A8E80L, "str_linux_boot_args", "Linux Boot Args: %s"));
		d60242.add(new LabelDef(0x810A074CL, "str_tp_handshake_init_fmt", "<<<<< %s sent initial handshake >>>>>>"));
		d60242.add(new LabelDef(0x810A07A0L, "str_tp_getmsg_handshake_err", "Error: getHostDqmMessage(handshake) on %s"));
		d60242.add(new LabelDef(0x810A07CCL, "str_tp_handshake_unexpected_err", "Error: handshake rx unexpected message"));
		d60242.add(new LabelDef(0x810A07F4L, "str_tp_handshake_reply_fmt", "<<<<< %s sent reply handshake message >>>>>>"));
		d60242.add(new LabelDef(0x810A0A2CL, "str_tp_init_service_handshake", "init_service_handshake"));
		d60242.add(new LabelDef(0x810A8AFCL, "str_tp_unexpected_fmt_hex", "%s unexpected message %08lx"));
		d60242.add(new LabelDef(0x810A8B9CL, "str_tp_unexpected_fmt_dec", "%s: unexpected message %d"));
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
		d60242.add(new LabelDef(0x803A2D94L, "fn_enet_snmp_register_handlers", "SNMP-related registration flow used by Ethernet init sequence."));
		d60242.add(new LabelDef(0x803A2F10L, "loc_enet_snmp_register_stage", "Internal stage inside SNMP registration flow (not a standalone function)."));
		d60242.add(new LabelDef(0x803A873CL, "fn_enet_gmac_init_step1", "Early GMAC init helper stage."));
		d60242.add(new LabelDef(0x803A8B30L, "fn_enet_gmac_init_step2", "GMAC core command bit staging by board profile and interface."));
		d60242.add(new LabelDef(0x803A8C10L, "fn_enet_gmac_init_core", "Core GMAC register init helper invoked from step1."));
		d60242.add(new LabelDef(0x803AE840L, "fn_enet_gmac_init_step6", "Main UNIMAC/MBDMA/PHY init stage with final command programming."));
		d60242.add(new LabelDef(0x803AED40L, "fn_enet_poll_or_wait_ready", "Wait/poll helper used by GMAC init step6."));
		d60242.add(new LabelDef(0x803AEFECL, "fn_enet_build_core_cmd", "Builds GMAC command and speed/duplex selection from PHY type and link mode."));
		profileLabels.put("d60242", d60242);

		List<LabelDef> dc0103 = new ArrayList<>();
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
	}
}
