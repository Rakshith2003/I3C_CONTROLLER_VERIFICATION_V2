class i3c_ral_reg_block extends uvm_reg_block;
  `uvm_object_utils(i3c_ral_reg_block)

  rand i3c_ctrl_reg     ctrl_inst;
  rand i3c_wdatab_reg   wdatab_inst;
       i3c_rdatab_reg   rdatab_inst;
       i3c_status_reg   status_inst;
       i3c_dynaddr_reg  dynaddr_inst;

  function new(string name = "ral_i3c_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  function void build();
   // uvm_reg::include_coverage("*", UVM_CVR_ALL);

    // CTRL REG (0x00C)

    ctrl_inst = i3c_ctrl_reg::type_id::create("ctrl_inst");
    ctrl_inst.build();
    ctrl_inst.configure(this);

    ctrl_inst.add_hdl_path_slice("cmd_addr",0, 7);
    ctrl_inst.add_hdl_path_slice("cmd_len",7, 8);
    ctrl_inst.add_hdl_path_slice("cmd_dir",15, 1);
    ctrl_inst.add_hdl_path_slice("cmd_ccc",      16, 8);
    ctrl_inst.add_hdl_path_slice("cmd_type", 24, 2);
    ctrl_inst.add_hdl_path_slice("cmd_mode", 26, 1);
    ctrl_inst.add_hdl_path_slice("reserved", 27, 4);
    ctrl_inst.add_hdl_path_slice("start",    31, 1);

  //  ctrl_inst.set_coverage(UVM_CVR_FIELD_VALS);


    // WDATAB REG (0x30)

    wdatab_inst = i3c_wdatab_reg::type_id::create("wdatab_inst");
    wdatab_inst.build();
    wdatab_inst.configure(this);
    wdatab_inst.add_hdl_path_slice("tx_data", 0, 8);
   // wdatab_inst.set_coverage(UVM_CVR_FIELD_VALS);

    // RDATAB REG (0x40)

    rdatab_inst = i3c_rdatab_reg::type_id::create("rdatab_inst");
    rdatab_inst.build();
    rdatab_inst.configure(this);

    rdatab_inst.add_hdl_path_slice("rx_data", 0, 8);

   //-----------------------------------
    // DYNADDR REG (0x064)
    //-----------------------------------

    dynaddr_inst =
      i3c_dynaddr_reg::type_id::create(
        "dynaddr_inst"
      );

    dynaddr_inst.build();
    dynaddr_inst.configure(this);

    dynaddr_inst.add_hdl_path_slice("dyn_addr",0,7);

//-----------------------------------
    // STATUS REG (0x008)
    //-----------------------------------

    status_inst =i3c_status_reg::type_id::create("status_inst");

    status_inst.build();
    status_inst.configure(this);
// HDL path for REG_STATUS backdoor access
status_inst.add_hdl_path_slice("x1.STATUS", 0, 17);

    default_map = create_map("default_map", 'h000, 4, UVM_LITTLE_ENDIAN);

    default_map.add_reg(ctrl_inst,    'h00C, "WO");
    default_map.add_reg(wdatab_inst,  'h030, "WO");
    default_map.add_reg(rdatab_inst,  'h040, "RO");
    default_map.add_reg(dynaddr_inst,  'h064, "RO");
    default_map.add_reg(status_inst,  'h008, "RO");

add_hdl_path("hdl_top.dut", "RTL");
    lock_model();

  endfunction

endclass

