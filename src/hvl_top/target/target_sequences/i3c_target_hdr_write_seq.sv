`ifndef I3C_TARGET_HDR_WRITE_SEQ_INCLUDED_
`define I3C_TARGET_HDR_WRITE_SEQ_INCLUDED_

class i3c_target_hdr_write_seq extends i3c_target_base_seq;
  `uvm_object_utils(i3c_target_hdr_write_seq)

  extern function new(string name = "i3c_target_hdr_write_seq");
  extern task body();
endclass : i3c_target_hdr_write_seq

function i3c_target_hdr_write_seq::new(string name = "i3c_target_hdr_write_seq");
  super.new(name);
endfunction : new

task i3c_target_hdr_write_seq::body();
  req = i3c_target_tx::type_id::create("req_hdr_write");
  start_item(req);

  `uvm_info(get_type_name(), "HDR WRITE: Before randomization - req created", UVM_NONE)

  req.targetAddress = p_sequencer.i3c_target_agent_cfg_h.targetAddress;
  req.operation      = I3C_WRITE;

  if (!req.randomize() with {
        txn_type             == i3c_target_tx::HDR_WRITE;
        targetAddressStatus  == ACK;
      }) begin
    `uvm_error(get_type_name(), "Randomization failed on HDR WRITE item")
  end else begin
    req.writeDataStatus = new[64];
    foreach (req.writeDataStatus[i])
      req.writeDataStatus[i] = ACK;

    `uvm_info(get_type_name(), "HDR WRITE: Randomization SUCCESS - after overrides", UVM_NONE)
    req.print();
  end

  finish_item(req);
  `uvm_info(get_type_name(), "HDR WRITE: finish_item returned - item sent to driver", UVM_NONE)
endtask : body

`endif

