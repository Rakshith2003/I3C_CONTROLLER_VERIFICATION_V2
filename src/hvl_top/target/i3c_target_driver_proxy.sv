`ifndef I3C_TARGET_DRIVER_PROXY_INCLUDED_
`define I3C_TARGET_DRIVER_PROXY_INCLUDED_

class i3c_target_driver_proxy extends uvm_driver #(i3c_target_tx);
  `uvm_component_utils(i3c_target_driver_proxy)

  i3c_target_agent_config  i3c_target_agent_cfg_h;
  virtual i3c_target_driver_bfm i3c_target_drv_bfm_h;
    static int daa_count = 0;
  extern function new(string name = "i3c_target_driver_proxy",
                      uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void end_of_elaboration_phase(uvm_phase phase);
  extern virtual task          run_phase(uvm_phase phase);
endclass : i3c_target_driver_proxy


function i3c_target_driver_proxy::new(string name = "i3c_target_driver_proxy",
                                      uvm_component parent = null);
  super.new(name, parent);
endfunction : new


function void i3c_target_driver_proxy::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

function void i3c_target_driver_proxy::end_of_elaboration_phase(uvm_phase phase);
  string bfm_key;
  super.end_of_elaboration_phase(phase);
  bfm_key = $sformatf("i3c_target_driver_bfm_%0d",
                       i3c_target_agent_cfg_h.target_id);
  `uvm_info("TGT_DRV_PROXY",
    $sformatf("Looking up BFM with key: %s", bfm_key), UVM_LOW)
  if (!uvm_config_db #(virtual i3c_target_driver_bfm)::get(
        this, "", bfm_key, i3c_target_drv_bfm_h)) begin
    `uvm_fatal("FATAL_SDP_CANNOT_GET_target_DRIVER_BFM",
      $sformatf("Cannot get i3c_target_driver_bfm from uvm_config_db. key=%s",
                bfm_key))
  end
  i3c_target_drv_bfm_h.i3c_target_drv_proxy_h = this;
endfunction : end_of_elaboration_phase

task i3c_target_driver_proxy::run_phase(uvm_phase phase);
  i3c_transfer_bits_s struct_packet;
  i3c_transfer_cfg_s  struct_cfg;
  bit [47:0] pid_out;
  bit [7:0]  bcr_out;
  bit [7:0]  dcr_out;
  bit [6:0]  dyn_addr_out;
  bit        daa_ack_out;
  super.run_phase(phase);
  i3c_target_drv_bfm_h.wait_for_system_reset();
  i3c_target_drv_bfm_h.drive_idle_state();
  forever begin
    seq_item_port.get_next_item(req);
    `uvm_info("TGT_DRV_PROXY",
      $sformatf("[target_id=%0d] Got item from sequencer, txn_type=%s",
                i3c_target_agent_cfg_h.target_id, req.txn_type.name()),
      UVM_NONE)
    i3c_target_cfg_converter::from_class(i3c_target_agent_cfg_h, struct_cfg);
    if (req.txn_type == i3c_target_tx::DAA) begin
      `uvm_info("TGT_DRV_PROXY",
        $sformatf("[target_id=%0d] DAA transaction",
                  i3c_target_agent_cfg_h.target_id), UVM_NONE)
      i3c_target_seq_item_converter::from_class(req, struct_packet);
      i3c_target_drv_bfm_h.drive_daa_data(
        struct_packet,
        struct_cfg,
        pid_out,
        bcr_out,
        dcr_out,
        dyn_addr_out,
        daa_ack_out
      );
      req.pid             = pid_out;
      req.bcr             = bcr_out;
      req.dcr             = dcr_out;
      req.dynamic_address = dyn_addr_out;
      req.daa_ack         = daa_ack_out;
      `uvm_info("TGT_DRV_PROXY",
        $sformatf("[target_id=%0d] DAA done: PID=0x%0h BCR=0x%0h DCR=0x%0h DynAddr=0x%0h ACK=%0b",
                  i3c_target_agent_cfg_h.target_id,
                  pid_out, bcr_out, dcr_out, dyn_addr_out, daa_ack_out),
        UVM_NONE)
      if (daa_ack_out == ACK) begin
        i3c_target_agent_cfg_h.targetAddress = dyn_addr_out;
        `uvm_info("TGT_DRV_PROXY",
          $sformatf("[target_id=%0d] Dynamic address 0x%0h stored in config",
                    i3c_target_agent_cfg_h.target_id, dyn_addr_out),
          UVM_LOW)
      end
    end else if (req.txn_type == i3c_target_tx::HOTJOIN) begin
      `uvm_info("TGT_DRV_PROXY",
        $sformatf("[target_id=%0d] HOTJOIN transaction, ibi_addr=0x%0h",
                  i3c_target_agent_cfg_h.target_id, req.hotjoin_addr), UVM_NONE)
      i3c_target_seq_item_converter::from_class(req, struct_packet);
      i3c_target_drv_bfm_h.drive_hot_join_data(
        req.hotjoin_addr,
        struct_packet,
        struct_cfg,
        pid_out,
        bcr_out,
        dcr_out,
        dyn_addr_out,
        daa_ack_out
      );
      req.pid             = pid_out;
      req.bcr             = bcr_out;
      req.dcr             = dcr_out;
      req.dynamic_address = dyn_addr_out;
      req.daa_ack         = daa_ack_out;
      `uvm_info("TGT_DRV_PROXY",
        $sformatf("[target_id=%0d] HOTJOIN done: PID=0x%0h BCR=0x%0h DCR=0x%0h DynAddr=0x%0h ACK=%0b",
                  i3c_target_agent_cfg_h.target_id,
                  pid_out, bcr_out, dcr_out, dyn_addr_out, daa_ack_out),
        UVM_NONE)
      if (daa_ack_out == ACK) begin
        i3c_target_agent_cfg_h.targetAddress = dyn_addr_out;
        `uvm_info("TGT_DRV_PROXY",
          $sformatf("[target_id=%0d] Dynamic address 0x%0h stored in config (via hot-join)",
                    i3c_target_agent_cfg_h.target_id, dyn_addr_out),
          UVM_LOW)
      end
    end else if (req.txn_type == i3c_target_tx::IBI) begin
      bit       ibi_ack_out;
      bit       t1_out;
      bit [7:0] extra_data_sent_out[];
      bit       extra_t_bits_out[];
      `uvm_info("TGT_DRV_PROXY",
        $sformatf("[target_id=%0d] IBI transaction, dynamic_address=0x%0h mdb=0x%0h num_extra_bytes=%0d",
                  i3c_target_agent_cfg_h.target_id,
                  i3c_target_agent_cfg_h.targetAddress, req.ibi_mdb,
                  req.ibi_num_extra_bytes), UVM_NONE)
      i3c_target_drv_bfm_h.drive_ibi_data(
        i3c_target_agent_cfg_h.targetAddress,
        req.ibi_mdb,
        req.ibi_num_extra_bytes,
        req.ibi_extra_data,
        ibi_ack_out,
        t1_out,
        extra_data_sent_out,
        extra_t_bits_out
      );
      req.dynamic_address    = i3c_target_agent_cfg_h.targetAddress;
      req.daa_ack             = ibi_ack_out;
      req.ibi_t1              = t1_out;
      req.ibi_extra_data_sent = extra_data_sent_out;
      req.ibi_extra_t_bits    = extra_t_bits_out;
      `uvm_info("TGT_DRV_PROXY",
        $sformatf("[target_id=%0d] IBI done: dynamic_address=0x%0h mdb=0x%0h ack=%0b T1=%0b extra_bytes_sent=%0d",
                  i3c_target_agent_cfg_h.target_id,
                  req.dynamic_address, req.ibi_mdb, ibi_ack_out,
                  t1_out, extra_data_sent_out.size()), UVM_NONE)
    end else if(req.txn_type == i3c_target_tx::HDR_WRITE) begin
`uvm_info("TGT_DRV_PROXY",
      "Transaction type = HDR_WRITE", UVM_NONE)
    i3c_target_seq_item_converter::from_class(req, struct_packet);
    i3c_target_drv_bfm_h.drive_hdr_write(
      struct_packet,
      struct_cfg
    );
    i3c_target_seq_item_converter::to_class(struct_packet, req);
  end
    else  if(req.txn_type == i3c_target_tx::HDR_READ) begin
`uvm_info("TGT_DRV_PROXY",
      "Transaction type = HDR_READ", UVM_NONE)
    i3c_target_seq_item_converter::from_class(req, struct_packet);
    i3c_target_drv_bfm_h.drive_hdr_read(
      struct_packet,
      struct_cfg
    );
    i3c_target_seq_item_converter::to_class(struct_packet, req);
  end
else begin
      // SDR TRANSACTION
      `uvm_info("TGT_DRV_PROXY",
        $sformatf("[target_id=%0d] SDR transaction",
                  i3c_target_agent_cfg_h.target_id), UVM_NONE)
      i3c_target_seq_item_converter::from_class(req, struct_packet);
      i3c_target_drv_bfm_h.drive_data(struct_packet, struct_cfg);
      i3c_target_seq_item_converter::to_class(struct_packet, req);
    end
    seq_item_port.item_done();
    `uvm_info("TGT_DRV_PROXY",
      $sformatf("[target_id=%0d] item_done", i3c_target_agent_cfg_h.target_id),
      UVM_NONE)
  end
endtask : run_phase
`endif

