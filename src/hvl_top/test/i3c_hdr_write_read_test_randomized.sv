class i3c_hdr_write_read_test_randomized extends i3c_base_test;
  `uvm_component_utils(i3c_hdr_write_read_test_randomized)
  i3c_daa_virtual_seq             daaSeq;
  i3c_hdr_write_read_virtual_seq_randomized  hdrWriteReadSeq;
  function new(string name = "i3c_hdr_write_read_test_randomized",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void setup_target_agent_cfg();
    super.setup_target_agent_cfg();
    foreach(i3c_env_cfg_h.i3c_target_agent_cfg_h[i]) begin
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].has_daa = 1;
  i3c_env_cfg_h.i3c_target_agent_cfg_h[i].pending_hdr_write = 1;  
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].pending_hdr_read  = 1;     
  end
  endfunction
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info(get_type_name(),
      "Starting DAA sequence", UVM_LOW)
    daaSeq = i3c_daa_virtual_seq::type_id::create("daaSeq");
    daaSeq.i3c_env_cfg_h = i3c_env_cfg_h;
    daaSeq.start(i3c_env_h.top_virtual_seqr_h);
    `uvm_info(get_type_name(),
      "DAA done - updating target address to dynamic 0x08",
      UVM_LOW)
    foreach(i3c_env_cfg_h.i3c_target_agent_cfg_h[i]) begin
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].targetAddress = 7'h08;
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].has_daa = 0;
    end
    `uvm_info(get_type_name(),
      "Starting HDR WRITE READ with dynamic address",
      UVM_LOW)
    hdrWriteReadSeq =
      i3c_hdr_write_read_virtual_seq_randomized::type_id::create("hdrWriteReadSeq");
    hdrWriteReadSeq.i3c_env_cfg_h = i3c_env_cfg_h;
    hdrWriteReadSeq.start(i3c_env_h.top_virtual_seqr_h);
    #50us;
    phase.drop_objection(this);
  endtask
endclass

