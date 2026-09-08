
`ifndef I3C_TARGET_READOPERATIONWITH8BITSDATA_SEQ_INCLUDED_ 
`define I3C_TARGET_READOPERATIONWITH8BITSDATA_SEQ_INCLUDED_

class i3c_target_readOperationWith8bitsData_seq extends i3c_target_base_seq;
  `uvm_object_utils(i3c_target_readOperationWith8bitsData_seq)
 int unsigned num_bytes = 1; 

   extern function new(string name = "i3c_target_readOperationWith8bitsData_seq");
   extern task body();
endclass : i3c_target_readOperationWith8bitsData_seq

function i3c_target_readOperationWith8bitsData_seq::new(string name = "i3c_target_readOperationWith8bitsData_seq");
  super.new(name);
endfunction : new


task i3c_target_readOperationWith8bitsData_seq::body();
  req = i3c_target_tx::type_id::create("req");
  start_item(req);

  `uvm_info(get_type_name(), "Before randomization - req created", UVM_NONE)

  req.targetAddress = p_sequencer.i3c_target_agent_cfg_h.targetAddress;
  req.operation     = I3C_READ;

  if(!req.randomize() with {
    targetAddressStatus == ACK;
  }) begin
    `uvm_error(get_type_name(), "Randomization failed")
  end else begin

    req.readData = new[num_bytes];
    foreach(req.readData[i])
      req.readData[i] = 8'h0; 

    `uvm_info(get_type_name(),
      $sformatf("Read seq ready: %0d bytes", num_bytes), UVM_LOW)
    req.print();
  end

  finish_item(req);
  `uvm_info(get_type_name(),
    "finish_item returned - item sent to driver", UVM_NONE)
endtask : body

`endif
