
`ifndef I3C_HDR_WRITE_READ_VIRTUAL_SEQ_LEN3_INCLUDED_
`define I3C_HDR_WRITE_READ_VIRTUAL_SEQ_LEN3_INCLUDED_
class i3c_hdr_write_read_virtual_seq_len3 extends top_virtual_base_seq;
  `uvm_object_utils(i3c_hdr_write_read_virtual_seq_len3)
  uvm_status_e   status;
  uvm_reg_data_t ctrl_val;
  uvm_reg_data_t rdata;
  rand bit [7:0] wdata[];
  rand bit [7:0] write_len;
  rand bit [7:0] read_len;
  constraint c {
    foreach (wdata[i])
      if (i == 0)
        wdata[i] == 11;
      else if (i == 1)
        wdata[i] == 22;
      else if (i == 2)
        wdata[i] == 33;
      else if (i == 3)
        wdata[i] == 44;
      else
        wdata[i] == 55;
  }
  constraint len_c {
    write_len inside {3};
    wdata.size() == write_len;
    read_len inside {2};
  }
  function new(string name = "i3c_hdr_write_read_virtual_seq_len3");
    super.new(name);
  endfunction
  task body();
    super.body();
    if (!this.randomize()) begin
      `uvm_error(get_type_name(), "Randomization failed — using defaults")
      write_len = 2;
      wdata     = new[2];
      wdata[0]  = 8'hA5;
      wdata[1]  = 8'h5A;
      read_len  = 2;
    end
    `uvm_info(get_type_name(), $sformatf(
      "HDR WRITE+READ: write_len=%0d write_data=%p  read_len=%0d",
      write_len, wdata, read_len), UVM_LOW)
    `uvm_info(get_type_name(), "=== PHASE 1: HDR WRITE ===", UVM_LOW)
    fork
      begin
        i3c_target_hdr_write_seq tgt_write;
        tgt_write = i3c_target_hdr_write_seq::type_id::create("tgt_write");
        tgt_write.start(p_sequencer.i3c_target_seqr_h[0]);
      end
    join_none
    `uvm_info(get_type_name(), "Step 1: Loading TX FIFO (WDATAB)", UVM_LOW)
    foreach (wdata[i]) begin
      i3c_env_cfg_h.regBlockHandle.wdatab_inst.write(
        status, wdata[i], .parent(this));
      `uvm_info(get_type_name(),
        $sformatf("  WDATAB[%0d] = %d", i, wdata[i]), UVM_LOW)
    end
    `uvm_info(get_type_name(),
      "Step 2: Writing CTRL (cmd_mode=1, dir=WRITE, start=1)", UVM_LOW)
    i3c_env_cfg_h.i3c_target_agent_cfg_h[0].hdr_mode = 1;
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_addr.set(
      i3c_env_cfg_h.i3c_target_agent_cfg_h[0].targetAddress);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_len.set(write_len);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_dir.set(1'b0);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_type.set(2'b00);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_mode.set(1'b1);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.start.set(1'b1);
    ctrl_val = i3c_env_cfg_h.regBlockHandle.ctrl_inst.get();
    `uvm_info(get_type_name(),
      $sformatf("  CTRL = 0x%08x", ctrl_val), UVM_LOW)
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.update(status, .parent(this));
    `uvm_info(get_type_name(),
      "Steps 3-13: DUT performs SDR address → HDR entry → DDR WRITE → STOP",
      UVM_LOW)
    #50us;
    i3c_env_cfg_h.i3c_target_agent_cfg_h[0].hdr_mode = 0;
    `uvm_info(get_type_name(), "Phase 1 (HDR WRITE) complete", UVM_LOW)
    `uvm_info(get_type_name(), "=== PHASE 2: HDR READ ===", UVM_LOW)
    fork
      begin
        i3c_target_hdr_read_seq tgt_read;
        tgt_read = i3c_target_hdr_read_seq::type_id::create("tgt_read");
        tgt_read.start(p_sequencer.i3c_target_seqr_h[0]);
      end
    join_none
    `uvm_info(get_type_name(),
      "Step 1: Writing CTRL (cmd_mode=1, dir=READ, start=1)", UVM_LOW)
    i3c_env_cfg_h.i3c_target_agent_cfg_h[0].hdr_mode = 1;
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_addr.set(
      i3c_env_cfg_h.i3c_target_agent_cfg_h[0].targetAddress);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_len.set(read_len);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_dir.set(1'b1);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_type.set(2'b01);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_mode.set(1'b1);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.start.set(1'b1);
    ctrl_val = i3c_env_cfg_h.regBlockHandle.ctrl_inst.get();
    `uvm_info(get_type_name(),
      $sformatf("  CTRL = 0x%08x", ctrl_val), UVM_LOW)
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.update(status, .parent(this));
    `uvm_info(get_type_name(),
      "Steps 2-11: DUT performs SDR address → HDR entry → DDR READ → STOP",
      UVM_LOW)
    #50us;
    i3c_env_cfg_h.i3c_target_agent_cfg_h[0].hdr_mode = 0;
    `uvm_info(get_type_name(),
      "Step 12: Reading RX FIFO via RDATAB", UVM_LOW)
    for (int i = 0; i < read_len; i++) begin
      i3c_env_cfg_h.regBlockHandle.rdatab_inst.read(status, rdata);
      `uvm_info(get_type_name(),
        $sformatf("  RDATAB[%0d] = 0x%02x", i, rdata[7:0]), UVM_LOW)
    end
    `uvm_info(get_type_name(), "Phase 2 (HDR READ) complete", UVM_LOW)
    `uvm_info(get_type_name(), "HDR WRITE+READ sequence complete", UVM_LOW)
  endtask
endclass
`endif

