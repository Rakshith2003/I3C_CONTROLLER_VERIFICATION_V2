`ifndef I3C_TARGET_MONITOR_PROXY_INCLUDED_
`define I3C_TARGET_MONITOR_PROXY_INCLUDED_

class i3c_target_monitor_proxy extends uvm_component;
  `uvm_component_utils(i3c_target_monitor_proxy)

  i3c_target_tx                      tx;
  i3c_target_agent_config            i3c_target_agent_cfg_h;
  virtual i3c_target_monitor_bfm     i3c_target_mon_bfm_h;
  uvm_analysis_port #(i3c_target_tx) target_analysis_port;
  uvm_analysis_port #(i3c_target_tx) ibi_analysis_port;
  localparam bit [7:0] BCAST_7E_W  = 8'hFC;
  localparam bit [7:0] ENTDAA_CODE = 8'h07;

  extern function new(string name = "i3c_target_monitor_proxy",
                      uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern virtual function void end_of_elaboration_phase(uvm_phase phase);
  extern virtual function void start_of_simulation_phase(uvm_phase phase);
  extern virtual task          run_phase(uvm_phase phase);
endclass : i3c_target_monitor_proxy


function i3c_target_monitor_proxy::new(
    string name = "i3c_target_monitor_proxy",
    uvm_component parent = null);
  super.new(name, parent);
  target_analysis_port = new("target_analysis_port", this);
  ibi_analysis_port     = new("ibi_analysis_port", this);
  tx = new();
endfunction : new


function void i3c_target_monitor_proxy::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase

function void i3c_target_monitor_proxy::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase


function void i3c_target_monitor_proxy::end_of_elaboration_phase(
    uvm_phase phase);
  string mon_key;
  super.end_of_elaboration_phase(phase);
  mon_key = $sformatf("i3c_target_monitor_bfm_%0d",
                       i3c_target_agent_cfg_h.target_id);
  `uvm_info("TGT_MON_PROXY",
    $sformatf("[target_id=%0d] Looking up monitor BFM with key: %s",
              i3c_target_agent_cfg_h.target_id, mon_key), UVM_LOW)
  if (!uvm_config_db #(virtual i3c_target_monitor_bfm)::get(
        this, "", mon_key, i3c_target_mon_bfm_h)) begin
    `uvm_fatal("FATAL_MDP_CANNOT_GET_target_MONITOR_BFM",
      $sformatf("Cannot get i3c_target_monitor_bfm from config_db. key=%s",
                mon_key))
  end
  i3c_target_mon_bfm_h.i3c_target_mon_proxy_h = this;
endfunction : end_of_elaboration_phase


function void i3c_target_monitor_proxy::start_of_simulation_phase(
    uvm_phase phase);
  super.start_of_simulation_phase(phase);
endfunction : start_of_simulation_phase


task i3c_target_monitor_proxy::run_phase(uvm_phase phase);
  i3c_transfer_bits_s struct_packet;
  i3c_transfer_cfg_s  struct_cfg;
  `uvm_info(get_type_name(),
    $sformatf("[target_id=%0d] Monitor Proxy running",
              i3c_target_agent_cfg_h.target_id), UVM_HIGH)
  i3c_target_mon_bfm_h.wait_for_reset();
  i3c_target_mon_bfm_h.sample_idle_state();
  forever begin
    if (i3c_target_agent_cfg_h != null &&
        i3c_target_agent_cfg_h.hotjoin_in_progress_elsewhere) begin
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] Hot-join in progress on another target - staying off the bus",
                  i3c_target_agent_cfg_h.target_id), UVM_HIGH)
      wait (!i3c_target_agent_cfg_h.hotjoin_in_progress_elsewhere);
      continue;
    end
    tx = i3c_target_tx::type_id::create("tx");
    i3c_target_cfg_converter::from_class(i3c_target_agent_cfg_h, struct_cfg);
    i3c_target_seq_item_converter::from_class(tx, struct_packet);
    `uvm_info(get_type_name(),
      $sformatf("[target_id=%0d] cfg snapshot -> targetAddress=0x%0h  pid=0x%0h  bcr=0x%0h  dcr=0x%0h  has_daa=%0b  pending_sdr=%0b",
                i3c_target_agent_cfg_h.target_id,
                struct_cfg.targetAddress,
                struct_cfg.pid,
                struct_cfg.bcr,
                struct_cfg.dcr,
                i3c_target_agent_cfg_h.has_daa,
                i3c_target_agent_cfg_h.pending_sdr),
      UVM_NONE)
    if (i3c_target_agent_cfg_h != null &&
        i3c_target_agent_cfg_h.pending_hot_join) begin
      bit [6:0] observed_ibi_addr;
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] Waiting to sample HOT JOIN transaction",
                  i3c_target_agent_cfg_h.target_id), UVM_HIGH)
      i3c_target_mon_bfm_h.sample_hot_join_data(
        struct_packet, struct_cfg, observed_ibi_addr);
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] HOTJOIN BFM returned struct -> ibi_addr=0x%0h  pid=0x%0h  bcr=0x%0h  dcr=0x%0h  daa_ack=%0b  dynamic_address=0x%0h",
                  i3c_target_agent_cfg_h.target_id,
                  observed_ibi_addr,
                  struct_packet.pid,
                  struct_packet.bcr,
                  struct_packet.dcr,
                  struct_packet.daa_ack,
                  struct_packet.dynamic_address),
        UVM_NONE)
      i3c_target_seq_item_converter::to_class(struct_packet, tx);
      tx.txn_type      = i3c_target_tx::DAA; 
      tx.hotjoin_addr  = observed_ibi_addr;
      i3c_target_agent_cfg_h.pending_hot_join = 0;
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] HOTJOIN tx -> txn_type=%s  ibi_addr=0x%0h  daa_ack=%0b  dynamic_address=0x%0h",
                  i3c_target_agent_cfg_h.target_id,
                  tx.txn_type.name(),
                  tx.hotjoin_addr,
                  tx.daa_ack,
                  tx.dynamic_address),
        UVM_NONE)
    end else if (i3c_target_agent_cfg_h != null &&
        i3c_target_agent_cfg_h.pending_ibi) begin
      bit [6:0] observed_ibi_dyn_addr;
      bit       observed_ibi_ack;
      bit [7:0] observed_ibi_mdb;
      bit       observed_ibi_t1;
      bit [7:0] observed_ibi_extra_data[];
      bit       observed_ibi_extra_t_bits[];
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] Waiting to sample IBI transaction",
                  i3c_target_agent_cfg_h.target_id), UVM_HIGH)

      i3c_target_mon_bfm_h.sample_ibi_data(
        observed_ibi_dyn_addr, observed_ibi_ack, observed_ibi_mdb,
        observed_ibi_t1, observed_ibi_extra_data, observed_ibi_extra_t_bits);
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] IBI BFM returned -> addr=0x%0h ack=%0b mdb=0x%0h T1=%0b extra_bytes=%0d",
                  i3c_target_agent_cfg_h.target_id,
                  observed_ibi_dyn_addr, observed_ibi_ack, observed_ibi_mdb,
                  observed_ibi_t1, observed_ibi_extra_data.size()),
        UVM_NONE)
      tx.txn_type             = i3c_target_tx::IBI;
      tx.dynamic_address      = observed_ibi_dyn_addr;
      tx.daa_ack               = observed_ibi_ack;
      tx.ibi_mdb               = observed_ibi_mdb;
      tx.ibi_num_extra_bytes   = observed_ibi_extra_data.size();
      tx.ibi_t1                = observed_ibi_t1;
      tx.ibi_extra_data_sent   = observed_ibi_extra_data;
      tx.ibi_extra_t_bits      = observed_ibi_extra_t_bits;
      i3c_target_agent_cfg_h.pending_ibi = 0;
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] IBI tx -> txn_type=%s addr=0x%0h ack=%0b mdb=0x%0h extra_bytes_sent=%0d",
                  i3c_target_agent_cfg_h.target_id, tx.txn_type.name(),
                  tx.dynamic_address, tx.daa_ack, tx.ibi_mdb,
                  tx.ibi_extra_data_sent.size()), UVM_NONE)
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] --> writing to DEDICATED ibi_analysis_port (scoreboard): txn_type=%s",
                  i3c_target_agent_cfg_h.target_id, tx.txn_type.name()),
        UVM_NONE)
      ibi_analysis_port.write(tx);
      continue;
    end else if (i3c_target_agent_cfg_h != null &&
        i3c_target_agent_cfg_h.pending_sdr) begin

      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] Waiting to sample SDR transaction (pending_sdr gated)",
                  i3c_target_agent_cfg_h.target_id), UVM_HIGH)
      i3c_target_mon_bfm_h.sample_data(struct_packet, struct_cfg);
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] SDR BFM returned struct -> targetAddress=0x%0h  targetAddressStatus=%0b  operation=%0s  no_of_bits=%0d",
                  i3c_target_agent_cfg_h.target_id,
                  struct_packet.targetAddress,
                  struct_packet.targetAddressStatus,
                  struct_packet.operation ? "READ" : "WRITE",
                  struct_packet.no_of_i3c_bits_transfer),
        UVM_NONE)
      if (struct_packet.operation == I3C_WRITE) begin
        for (int b = 0; b < MAXIMUM_BYTES; b++) begin
          if (b * I3C_DATA_WIDTH < struct_packet.no_of_i3c_bits_transfer) begin
            `uvm_info(get_type_name(),
              $sformatf("[target_id=%0d] SDR write data[%0d] = 0x%0h",
                        i3c_target_agent_cfg_h.target_id, b,
                        struct_packet.writeData[b]),
              UVM_NONE)
          end
        end
      end
      i3c_target_seq_item_converter::to_class(struct_packet, tx);
      i3c_target_agent_cfg_h.pending_sdr = 0;
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] SDR tx -> txn_type=%s  targetAddress=0x%0h  targetAddressStatus=%0b  operation=%0s",
                  i3c_target_agent_cfg_h.target_id,
                  tx.txn_type.name(),
                  tx.targetAddress,
                  tx.targetAddressStatus,
                  tx.operation.name()),
        UVM_NONE)
    end else if (i3c_target_agent_cfg_h != null &&
        i3c_target_agent_cfg_h.has_daa) begin
      bit hotjoin_interrupted;
      bit ibi_interrupted;
      bit sdr_interrupted;
      hotjoin_interrupted = 0;
      ibi_interrupted     = 0;
      sdr_interrupted     = 0;
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] Waiting to sample DAA transaction",
                  i3c_target_agent_cfg_h.target_id), UVM_HIGH)
      fork
        begin : do_daa_sample
          i3c_target_mon_bfm_h.sample_daa_data(struct_packet, struct_cfg);
        end
        begin : abort_on_hotjoin
          wait (i3c_target_agent_cfg_h.hotjoin_in_progress_elsewhere);
          hotjoin_interrupted = 1;
        end
        begin : abort_on_ibi
          wait (i3c_target_agent_cfg_h.pending_ibi);
          ibi_interrupted = 1;
        end
        begin : abort_on_sdr
          wait (i3c_target_agent_cfg_h.pending_sdr);
          sdr_interrupted = 1;
        end
      join_any
      disable fork;
      if (hotjoin_interrupted) begin
        `uvm_info(get_type_name(),
          $sformatf("[target_id=%0d] Aborting in-flight DAA sample - hot-join started on another target",
                    i3c_target_agent_cfg_h.target_id), UVM_HIGH)
        continue;
      end
      if (ibi_interrupted) begin
        `uvm_info(get_type_name(),
          $sformatf("[target_id=%0d] Aborting in-flight DAA sample - IBI requested on this target",
                    i3c_target_agent_cfg_h.target_id), UVM_HIGH)
        continue;
      end
      if (sdr_interrupted) begin
        `uvm_info(get_type_name(),
          $sformatf("[target_id=%0d] Aborting in-flight DAA sample - SDR requested on this target",
                    i3c_target_agent_cfg_h.target_id), UVM_HIGH)
        continue;
      end
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] DAA BFM returned struct -> pid=0x%0h  bcr=0x%0h  dcr=0x%0h  daa_ack=%0b  dynamic_address=0x%0h",
                  i3c_target_agent_cfg_h.target_id,
                  struct_packet.pid,
                  struct_packet.bcr,
                  struct_packet.dcr,
                  struct_packet.daa_ack,
                  struct_packet.dynamic_address),
        UVM_NONE)
      i3c_target_seq_item_converter::to_class(struct_packet, tx);
      tx.txn_type = i3c_target_tx::DAA;
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] DAA tx -> txn_type=%s  pid=0x%0h  bcr=0x%0h  dcr=0x%0h  daa_ack=%0b  dynamic_address=0x%0h",
                  i3c_target_agent_cfg_h.target_id,
                  tx.txn_type.name(),
                  tx.pid,
                  tx.bcr,
                  tx.dcr,
                  tx.daa_ack,
                  tx.dynamic_address),
        UVM_NONE)
    end else begin
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] Waiting to sample SDR transaction (fallback, has_daa=0)",
                  i3c_target_agent_cfg_h.target_id), UVM_HIGH)
      i3c_target_mon_bfm_h.sample_data(struct_packet, struct_cfg);
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] SDR BFM returned struct -> targetAddress=0x%0h  targetAddressStatus=%0b  operation=%0s  no_of_bits=%0d",
                  i3c_target_agent_cfg_h.target_id,
                  struct_packet.targetAddress,
                  struct_packet.targetAddressStatus,
                  struct_packet.operation ? "READ" : "WRITE",
                  struct_packet.no_of_i3c_bits_transfer),
        UVM_NONE)
      // Log write data bytes if it was a write operation
      if (struct_packet.operation == I3C_WRITE) begin
        for (int b = 0; b < MAXIMUM_BYTES; b++) begin
          if (b * I3C_DATA_WIDTH < struct_packet.no_of_i3c_bits_transfer) begin
            `uvm_info(get_type_name(),
              $sformatf("[target_id=%0d] SDR write data[%0d] = 0x%0h",
                        i3c_target_agent_cfg_h.target_id, b,
                        struct_packet.writeData[b]),
              UVM_NONE)
          end
        end
      end
      i3c_target_seq_item_converter::to_class(struct_packet, tx);
      `uvm_info(get_type_name(),
        $sformatf("[target_id=%0d] SDR tx -> txn_type=%s  targetAddress=0x%0h  targetAddressStatus=%0b  operation=%0s",
                  i3c_target_agent_cfg_h.target_id,
                  tx.txn_type.name(),
                  tx.targetAddress,
                  tx.targetAddressStatus,
                  tx.operation.name()),
        UVM_NONE)
    end
    `uvm_info(get_type_name(),
      $sformatf("[target_id=%0d] --> writing to analysis port (scoreboard): txn_type=%s",
                i3c_target_agent_cfg_h.target_id, tx.txn_type.name()),
      UVM_NONE)
    target_analysis_port.write(tx);
  end // forever
endtask : run_phase
`endif
