`ifndef I3C_SDR_WRITE_VIRTUAL_SEQ_LEN_1_INCLUDED_
`define I3C_SDR_WRITE_VIRTUAL_SEQ_LEN_1_INCLUDED_

class i3c_sdr_write_virtual_seq_len_1 extends top_virtual_base_seq;

  `uvm_object_utils(i3c_sdr_write_virtual_seq_len_1)

  uvm_status_e   status;
  uvm_reg_data_t ctrl_val;
  uvm_reg_data_t ctrl_mirror;
  uvm_reg_data_t status_reg_val;

  int unsigned target_idx = 0;

  rand bit [7:0] wdata_bytes[0:7];
  rand int unsigned transfer_len;

  constraint len_c {
    transfer_len == 1;
  }

  constraint wdata_val_c {
    foreach (wdata_bytes[i])
      wdata_bytes[i] inside {[8'h01:8'hFF]};
  }

  function new(string name = "i3c_sdr_write_virtual_seq_len_1");
    super.new(name);
  endfunction

  task body();

    i3c_target_writeOperationWith8bitsData_seq target_seq_write;
    int timeout;

    if (i3c_env_cfg_h == null)
      `uvm_fatal("CFG_NULL",
        "i3c_env_cfg_h is NULL inside i3c_sdr_write_virtual_seq")

    if (i3c_env_cfg_h.regBlockHandle == null)
      `uvm_fatal("RAL_NULL",
        "regBlockHandle is NULL inside i3c_sdr_write_virtual_seq")

    super.body();

    if (!this.randomize()) begin
      `uvm_error(get_type_name(), "Randomization failed - using defaults")
      transfer_len   = 1;
      wdata_bytes[0] = 8'h44;
    end

    `uvm_info(get_type_name(),
      $sformatf("SDR WRITE to target[%0d] addr=0x%0h len=%0d bytes",
                target_idx,
                i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].targetAddress,
                transfer_len),
      UVM_LOW)

    foreach (wdata_bytes[i])
      if (i < transfer_len)
        `uvm_info(get_type_name(),
          $sformatf("  planned payload[%0d] = 0x%02h", i, wdata_bytes[i]),
          UVM_LOW)

    // Tell target monitor that next START is SDR

    // Launch target-side sequence
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

    // Load WDATAB FIFO
    for (int i = 0; i < transfer_len; i++) begin

      `uvm_info(get_type_name(),
        $sformatf("Pushing WDATAB[%0d] = 0x%02h", i, wdata_bytes[i]),
        UVM_LOW)

      i3c_env_cfg_h.regBlockHandle.wdatab_inst.write(
        status,
        uvm_reg_data_t'(wdata_bytes[i]),
        UVM_FRONTDOOR,
        .parent(this));

      if (status != UVM_IS_OK)
        `uvm_error(get_type_name(),
          $sformatf("WDATAB[%0d] write failed", i))
      else
        `uvm_info(get_type_name(),
          $sformatf("WDATAB[%0d] write OK", i),
          UVM_LOW)
    end

    `uvm_info(get_type_name(),
      $sformatf("All %0d bytes loaded into WDATAB FIFO", transfer_len),
      UVM_LOW)

    // Program CTRL
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
      $sformatf("CTRL before SDR write = 0x%08h addr=0x%0h len=%0d",
                ctrl_val,
                i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].targetAddress,
                transfer_len),
      UVM_LOW)

    i3c_env_cfg_h.regBlockHandle.ctrl_inst.update(status, .parent(this));

    ctrl_mirror =
      i3c_env_cfg_h.regBlockHandle.ctrl_inst.get_mirrored_value();

    `uvm_info("CTRL_DEBUG",
      $sformatf("CTRL mirrored after write = 0x%08h", ctrl_mirror),
      UVM_LOW)

    i3c_env_cfg_h.regBlockHandle.ctrl_inst.mirror(status, UVM_NO_CHECK);

    // ------------------------------------------------------------
    // Wait for CMD_BUSY to assert
    // ------------------------------------------------------------
    timeout = 1000;

    while (timeout > 0) begin

      i3c_env_cfg_h.regBlockHandle.status_inst.read(
        status,
        status_reg_val,
        UVM_BACKDOOR,
        .parent(this));

      if (status != UVM_IS_OK)
        `uvm_fatal(get_type_name(), "REG_STATUS backdoor read failed")

      if (status_reg_val[0]) begin
        `uvm_info(get_type_name(),
          $sformatf("CMD_BUSY asserted. REG_STATUS=0x%08h",
                    status_reg_val),
          UVM_LOW)
        break;
      end

      #10;
      timeout--;
    end

    if (timeout == 0)
      `uvm_error(get_type_name(),
        "Timeout waiting for CMD_BUSY to assert")

    // ------------------------------------------------------------
    // Wait for CMD_BUSY to deassert
    // ------------------------------------------------------------
    timeout = 1000;

    while (timeout > 0) begin

      i3c_env_cfg_h.regBlockHandle.status_inst.read(
        status,
        status_reg_val,
        UVM_BACKDOOR,
        .parent(this));

      if (status != UVM_IS_OK)
        `uvm_fatal(get_type_name(), "REG_STATUS backdoor read failed")

      if (!status_reg_val[0]) begin
        `uvm_info(get_type_name(),
          $sformatf("CMD_BUSY deasserted. REG_STATUS=0x%08h",
                    status_reg_val),
          UVM_LOW)
        break;
      end

      #10;
      timeout--;
    end

    if (timeout == 0)
      `uvm_error(get_type_name(),
        "Timeout waiting for CMD_BUSY to deassert")

    // ------------------------------------------------------------
    // Final REG_STATUS backdoor read
    // ------------------------------------------------------------
    i3c_env_cfg_h.regBlockHandle.status_inst.read(
      status,
      status_reg_val,
      UVM_BACKDOOR,
      .parent(this));

    if (status != UVM_IS_OK)
      `uvm_error(get_type_name(), "Final REG_STATUS backdoor read failed")
    else begin
      `uvm_info("REG_STATUS_BKDR",
        $sformatf(
          "REG_STATUS=0x%08h | CMD_BUSY=%0b SDR_BUSY=%0b SDR_DONE=%0b DAA_DONE=%0b DAA_BUSY=%0b TX_FULL=%0b TX_EMPTY=%0b RX_FULL=%0b RX_EMPTY=%0b SDR_BIT_DONE=%0b SDR_BIT_BUSY=%0b BUS_IDLE=%0b HDR_BUSY=%0b HDR_DONE=%0b HDR_BIT_DONE=%0b HDR_BIT_BUSY=%0b IRQ=%0b",
          status_reg_val,
          status_reg_val[0],
          status_reg_val[1],
          status_reg_val[2],
          status_reg_val[3],
          status_reg_val[4],
          status_reg_val[5],
          status_reg_val[6],
          status_reg_val[7],
          status_reg_val[8],
          status_reg_val[9],
          status_reg_val[10],
          status_reg_val[11],
          status_reg_val[12],
          status_reg_val[13],
          status_reg_val[14],
          status_reg_val[15],
          status_reg_val[16]),
        UVM_LOW)
    end

          i3c_env_cfg_h.i3c_target_agent_cfg_h[target_idx].pending_sdr = 0;


    `uvm_info(get_type_name(),
      $sformatf("SDR WRITE to target[%0d] complete (%0d bytes)",
                target_idx, transfer_len),
      UVM_LOW)

  endtask : body

endclass : i3c_sdr_write_virtual_seq_len_1

`endif

