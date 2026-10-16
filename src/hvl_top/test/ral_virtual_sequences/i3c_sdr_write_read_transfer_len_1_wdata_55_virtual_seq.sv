`ifndef I3C_SDR_WRITE_READ_TRANSFER_LEN_1_WDATA_55_VIRTUAL_SEQ_INCLUDED_
`define I3C_SDR_WRITE_READ_TRANSFER_LEN_1_WDATA_55_VIRTUAL_SEQ_INCLUDED_
class i3c_sdr_write_read_transfer_len_1_wdata_55_virtual_seq extends top_virtual_base_seq;
  `uvm_object_utils(i3c_sdr_write_read_transfer_len_1_wdata_55_virtual_seq)
  uvm_status_e   status;
  uvm_reg_data_t ctrl_val;
  uvm_reg_data_t ctrl_mirror;
  int unsigned target_idx = 0;
  rand bit [7:0] wdata_bytes [0:15];
  rand int unsigned transfer_len;
  constraint len_c {
    transfer_len == 1;
  }
  constraint wdata_val_c {
    foreach (wdata_bytes[i]) {
      wdata_bytes[i] == 8'h55;
    }
  }
  function new(string name = "i3c_sdr_write_read_transfer_len_1_wdata_55_virtual_seq");
    super.new(name);
  endfunction
  // -----------------------------------------------------------------
  // FIXED -- original paste had stray markdown code-fence artifacts
  // (```) embedded inside the task body (not valid SystemVerilog).
  // Removed below; logic is otherwise unchanged from the paste.
  // -----------------------------------------------------------------
  task body();
    i3c_target_writeOperationWith8bitsData_seq target_seq_write;
    i3c_target_readOperationWith8bitsData_seq  target_seq_read;
    if (i3c_env_cfg_h == null)
      `uvm_fatal("CFG_NULL", "i3c_env_cfg_h is NULL")
    if (i3c_env_cfg_h.regBlockHandle == null)
      `uvm_fatal("RAL_NULL", "regBlockHandle is NULL")
    super.body();
    if (!this.randomize()) begin
      `uvm_error(get_type_name(), "Randomization failed - using defaults")
      transfer_len   = 1;
      wdata_bytes[0] = 8'h55;
    end
    `uvm_info(get_type_name(),
      $sformatf("SDR WRITE+READ to target[%0d] addr=0x%0h len=%0d bytes",
                target_idx,
                i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].targetAddress,
                transfer_len),
      UVM_LOW)
    for (int i = 0; i < transfer_len; i++)
      `uvm_info(get_type_name(),
        $sformatf("planned payload[%0d] = 0x%02h", i, wdata_bytes[i]),
        UVM_LOW)
    // -----------------------------------------------------------------
    // pending_sdr -- ADDED. Missing from the original paste, same gap
    // as the other write+read sequences. Re-asserted before the READ
    // block below since the proxy clears it after the write frame.
    // -----------------------------------------------------------------
    i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].pending_sdr = 1;
    fork
      begin
        target_seq_write =
          i3c_target_writeOperationWith8bitsData_seq::type_id::create(
            "target_seq_write");
        target_seq_write.start(
          p_sequencer.i3c_target_seqr_h[target_idx]);
      end
    join_none
    for (int i = 0; i < transfer_len; i++) begin
      `uvm_info(get_type_name(),
        $sformatf("WRITE: pushing WDATAB[%0d] = 0x%02h", i, wdata_bytes[i]),
        UVM_LOW)
      i3c_env_cfg_h.regBlockHandle.wdatab_inst.write(
        status, uvm_reg_data_t'(wdata_bytes[i]),
        UVM_FRONTDOOR, .parent(this));
      if (status != UVM_IS_OK)
        `uvm_error(get_type_name(),
          $sformatf("WDATAB write[%0d]=0x%02h failed", i, wdata_bytes[i]))
    end
    `uvm_info(get_type_name(),
      $sformatf("WRITE: all %0d bytes loaded into WDATAB FIFO", transfer_len),
      UVM_LOW)
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_addr.set(
      i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].targetAddress);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_len.set(transfer_len);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_dir.set(1'b0);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_type.set(2'd0);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_ccc.set(8'd0);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_mode.set(1'b0);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.start.set(1'b1);
    ctrl_val = i3c_env_cfg_h.regBlockHandle.ctrl_inst.get();
    `uvm_info("CTRL_DEBUG",
      $sformatf("WRITE CTRL = 0x%0h addr=0x%0h len=%0d",
                ctrl_val,
                i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].targetAddress,
                transfer_len),
      UVM_LOW)
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.update(status, .parent(this));
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.mirror(status, UVM_NO_CHECK);
    #(5000 * (transfer_len + 2));
    `uvm_info(get_type_name(),
      $sformatf("WRITE to target[%0d] complete", target_idx),
      UVM_LOW)
    // -----------------------------------------------------------------
    // pending_sdr -- ADDED. Belt-and-braces clear after the write frame.
    // -----------------------------------------------------------------
    i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].pending_sdr = 0;
    // -----------------------------------------------------------------
    // pending_sdr -- ADDED. Re-assert before the READ frame.
    // -----------------------------------------------------------------
    i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].pending_sdr = 1;
    fork
      begin
        target_seq_read =
          i3c_target_readOperationWith8bitsData_seq::type_id::create(
            "target_seq_read");
        target_seq_read.start(
          p_sequencer.i3c_target_seqr_h[target_idx]);
      end
    join_none
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_addr.set(
      i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].targetAddress);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_len.set(transfer_len);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_dir.set(1'b1);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_type.set(2'd1);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_ccc.set(8'd0);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.cmd_mode.set(1'b0);
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.start.set(1'b1);
    ctrl_val = i3c_env_cfg_h.regBlockHandle.ctrl_inst.get();
    `uvm_info("CTRL_DEBUG",
      $sformatf("READ CTRL = 0x%0h addr=0x%0h len=%0d",
                ctrl_val,
                i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].targetAddress,
                transfer_len),
      UVM_LOW)
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.update(status, .parent(this));
    i3c_env_cfg_h.regBlockHandle.ctrl_inst.mirror(status, UVM_NO_CHECK);
    #(5000 * (transfer_len + 2));
    `uvm_info(get_type_name(),
      $sformatf("READ from target[%0d]: reading back %0d bytes from RDATAB",
                target_idx, transfer_len),
      UVM_LOW)
    // -----------------------------------------------------------------
    // pending_sdr -- ADDED. Belt-and-braces clear after the read frame.
    // -----------------------------------------------------------------
    i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].pending_sdr = 0;
    for (int i = 0; i < transfer_len; i++) begin
      uvm_reg_data_t rdata;
      i3c_env_cfg_h.regBlockHandle.rdatab_inst.read(
        status, rdata, UVM_FRONTDOOR, .parent(this));
    end
    `uvm_info(get_type_name(),
      $sformatf("SDR WRITE+READ to target[%0d] complete (%0d bytes)",
                target_idx, transfer_len),
      UVM_LOW)
  endtask : body
endclass : i3c_sdr_write_read_transfer_len_1_wdata_55_virtual_seq
`endif
