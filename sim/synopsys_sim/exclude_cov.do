coverage open merged_coverage.ucdb

# ── Existing line exclusions ────────────────────────────────
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 100
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 103
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 83
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 67
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 65
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 69
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 64
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 92
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 96
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 174
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 32
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 97
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 248
coverage exclude -srcfile "../../rtl_dev/src/I3C_TOP.v" -line 91

coverage exclude -srcfile "../../src/hdl_top/apb_master_agent_bfm/apb_master_driver_bfm.sv"
coverage exclude -srcfile "../../src/hdl_top/apb_master_agent_bfm/apb_master_monitor_bfm.sv"

coverage exclude -srcfile "../../src/hvl_top/apb_master/apb_master_agent.sv"
coverage exclude -srcfile "../../src/hvl_top/apb_master/apb_master_coverage.sv"
coverage exclude -srcfile "../../src/hvl_top/apb_master/apb_master_driver_proxy.sv"
coverage exclude -srcfile "../../src/hvl_top/apb_master/apb_master_monitor_proxy.sv"
coverage exclude -srcfile "../../src/hvl_top/apb_master/apb_master_sequencer.sv"
coverage exclude -srcfile "../../src/hvl_top/apb_master/apb_master_seq_item_converter.sv"
coverage exclude -srcfile "../../src/hvl_top/apb_master/apb_master_cfg_converter.sv"


coverage exclude -srcfile "../../src/hdl_top/apb_if/apb_if.sv"

coverage exclude -srcfile "../../src/hdl_top/controller_agent_bfm/i3c_controller_agent_bfm.sv"
coverage exclude -srcfile "../../src/hdl_top/controller_agent_bfm/i3c_controller_driver_bfm.sv"
coverage exclude -srcfile "../../src/hdl_top/controller_agent_bfm/i3c_controller_monitor_bfm.sv"


coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_agent.sv"
coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_agent_config.sv"
coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_cfg_converter.sv"
coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_coverage.sv"
coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_driver_proxy.sv"
coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_monitor_proxy.sv"
coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_seq_item_converter.sv"
coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_sequencer.sv"
coverage exclude -srcfile "../../src/hvl_top/controller//i3c_controller_tx.sv"

# ============================================================
# CONTROLLER SEQUENCES
# ============================================================

coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_base_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_randomOperationWithRandomDataTransferWidth_seq.sv"

coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_readOperationWith16bitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_readOperationWith32bitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_readOperationWith64bitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_readOperationWith8bitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_readOperationWithMaximumbitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_readOperationWithRandomDataTransferWidth_seq.sv"

coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_writeOperationWith16bitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_writeOperationWith32bitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_writeOperationWith64bitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_writeOperationWith8bitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_writeOperationWithMaximumbitsData_seq.sv"
coverage exclude -srcfile "../../src/hvl_top/controller/controller_sequences//i3c_controller_writeOperationWithRandomDataTransferWidth_seq.sv"


coverage save merged_coverage.ucdb
quit
