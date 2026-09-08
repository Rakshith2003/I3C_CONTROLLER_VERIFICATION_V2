`ifndef I3C_TARGET_SEQ_ITEM_CONVERTER_INCLUDED_
`define I3C_TARGET_SEQ_ITEM_CONVERTER_INCLUDED_

class i3c_target_seq_item_converter extends uvm_object;

  extern function new(string name="i3c_target_seq_item_converter");

  extern static function void from_class(
      input i3c_target_tx input_conv_h,
      output i3c_transfer_bits_s output_conv
  );

  extern static function void to_class(
      input i3c_transfer_bits_s input_conv_h,
      output i3c_target_tx output_conv
  );

  extern function void do_print(uvm_printer printer);

endclass


function i3c_target_seq_item_converter::new(string name =
                                            "i3c_target_seq_item_converter");
  super.new(name);
endfunction




function void i3c_target_seq_item_converter::from_class(
     input i3c_target_tx input_conv_h,
     output i3c_transfer_bits_s output_conv
);

  
  output_conv.targetAddressStatus =
      acknowledge_e'(input_conv_h.targetAddressStatus);

  output_conv.targetAddress = input_conv_h.targetAddress;

  output_conv.operation =
      operationType_e'(input_conv_h.operation);



  for(int i=0;i<input_conv_h.readData.size();i++)
    output_conv.readData[i] = input_conv_h.readData[i];

  for(int i=0;i<input_conv_h.writeData.size();i++)
    output_conv.writeData[i] = input_conv_h.writeData[i];

  for(int i=0;i<input_conv_h.writeDataStatus.size();i++)
    output_conv.writeDataStatus[i] =
        input_conv_h.writeDataStatus[i];

  for(int i=0;i<input_conv_h.readDataStatus.size();i++)
    output_conv.readDataStatus[i] =
        input_conv_h.readDataStatus[i];


 
output_conv.txn_type = bit'(input_conv_h.txn_type);
output_conv.pid             = input_conv_h.pid;
  output_conv.bcr             = input_conv_h.bcr;
  output_conv.dcr             = input_conv_h.dcr;
  output_conv.dynamic_address = input_conv_h.dynamic_address;
  output_conv.daa_ack         = input_conv_h.daa_ack;

endfunction





function void i3c_target_seq_item_converter::to_class(
     input i3c_transfer_bits_s input_conv_h,
     output i3c_target_tx output_conv
);
int byte_count;
  output_conv = new();



  output_conv.targetAddress =
      input_conv_h.targetAddress;

  output_conv.targetAddressStatus =
      acknowledge_e'(input_conv_h.targetAddressStatus);

  output_conv.operation =
      operationType_e'(input_conv_h.operation);


 


  byte_count = input_conv_h.no_of_i3c_bits_transfer / I3C_DATA_WIDTH;

  output_conv.readData = new[byte_count];
  output_conv.readDataStatus = new[byte_count];

  for(int i=0;i<byte_count;i++)
  begin
    output_conv.readData[i] =
        input_conv_h.readData[i][I3C_DATA_WIDTH-1:0];

    output_conv.readDataStatus[i] =
        acknowledge_e'(input_conv_h.readDataStatus[i]);
  end


  output_conv.writeData = new[byte_count];
  output_conv.writeDataStatus = new[byte_count];

  for(int i=0;i<byte_count;i++)
  begin
    output_conv.writeData[i] =
        input_conv_h.writeData[i];

    output_conv.writeDataStatus[i] =
        acknowledge_e'(input_conv_h.writeDataStatus[i]);
  end


  

output_conv.txn_type = i3c_target_tx::txn_type_e'(input_conv_h.txn_type);
  output_conv.pid             = input_conv_h.pid;
  output_conv.bcr             = input_conv_h.bcr;
  output_conv.dcr             = input_conv_h.dcr;
  output_conv.dynamic_address = input_conv_h.dynamic_address;
  output_conv.daa_ack         = input_conv_h.daa_ack;

endfunction




function void i3c_target_seq_item_converter::do_print(
     uvm_printer printer
);

  i3c_transfer_bits_s i3c_st;

  super.do_print(printer);

  printer.print_field("targetAddress",
                      i3c_st.targetAddress,
                      8,
                      UVM_HEX);

  foreach(i3c_st.writeData[i])
    printer.print_field($sformatf("writeData[%0d]",i),
                        i3c_st.writeData[i],
                        8,
                        UVM_HEX);

endfunction

`endif
