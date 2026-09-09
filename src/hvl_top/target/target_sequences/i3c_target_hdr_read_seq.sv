`ifndef I3C_TARGET_HDR_READ_SEQ_INCLUDED_
`define I3C_TARGET_HDR_READ_SEQ_INCLUDED_

// HDR-DDR READ target-side responder sequence -- NEW, additive only.
// Modeled on i3c_target_readOperationWith8bitsData_seq (the SDR read
// responder); the only difference is txn_type is forced to
// i3c_target_tx::HDR_READ so i3c_target_driver_proxy dispatches to
// i3c_target_driver_bfm::drive_hdr_read instead of drive_data. Launched
// from i3c_hdr_write_read_virtual_seq (and its len2/len3/len4/randomized
// variants) via fork/join_none, exactly like the SDR read responder.
class i3c_target_hdr_read_seq extends i3c_target_base_seq;
  `uvm_object_utils(i3c_target_hdr_read_seq)
  int unsigned num_bytes = 2;

  extern function new(string name = "i3c_target_hdr_read_seq");
  extern task body();
endclass : i3c_target_hdr_read_seq

function i3c_target_hdr_read_seq::new(string name = "i3c_target_hdr_read_seq");
  super.new(name);
endfunction : new

task i3c_target_hdr_read_seq::body();
  req = i3c_target_tx::type_id::create("req_hdr_read");
  start_item(req);

  `uvm_info(get_type_name(), "HDR READ: Before randomization - req created", UVM_NONE)

  req.targetAddress = p_sequencer.i3c_target_agent_cfg_h.targetAddress;
  req.operation      = I3C_READ;

  if (!req.randomize() with {
        txn_type             == i3c_target_tx::HDR_READ;
        targetAddressStatus  == ACK;
      }) begin
    `uvm_error(get_type_name(), "Randomization failed on HDR READ item")
  end else begin
    req.readData = new[num_bytes];
    foreach (req.readData[i])
      req.readData[i] = 8'h0;

    `uvm_info(get_type_name(),
      $sformatf("HDR READ seq ready: %0d bytes", num_bytes), UVM_LOW)
    req.print();
  end

  finish_item(req);
  `uvm_info(get_type_name(), "HDR READ: finish_item returned - item sent to driver", UVM_NONE)
endtask : body

`endif

