`ifndef I3C_TARGET_TX_INCLUDED_
`define I3C_TARGET_TX_INCLUDED_
class i3c_target_tx extends uvm_sequence_item;
  `uvm_object_utils(i3c_target_tx)
  rand bit [I3C_DATA_WIDTH-1:0]       readData[];
  rand acknowledge_e              targetAddressStatus;
  rand acknowledge_e              writeDataStatus[];
       operationType_e            operation;
       bit [TARGET_ADDRESS_WIDTH-1:0] targetAddress;
       bit [I3C_DATA_WIDTH-1:0]       writeData[];
       acknowledge_e              readDataStatus[];
  rand bit [31:0]                 size;
  

  typedef enum bit [2:0] {
    SDR       = 3'b000,
    DAA       = 3'b001,
    HOTJOIN   = 3'b010,
    IBI       = 3'b011,
    HDR_WRITE = 3'b100,
    HDR_READ  = 3'b101
  } txn_type_e;


  rand txn_type_e   txn_type;
  rand bit [47:0]   pid;
  rand bit [7:0]    bcr;
  rand bit [7:0]    dcr;
       bit [6:0]    dynamic_address;
       bit          daa_ack;
  rand bit [6:0]    hotjoin_addr;
  rand bit [7:0]    ibi_mdb;
  // HDR-DDR 


  rand bit [15:0]   hdr_data[$];
  bit [4:0]         hdr_crc;
  bit               hdr_parity;
  bit               hdr_tbit;

  
  rand int unsigned ibi_num_extra_bytes;    // # of bytes beyond the MDB the target intends to send
  rand bit [7:0]    ibi_extra_data[];       // values of those bytes (size == ibi_num_extra_bytes)


  bit               ibi_t1;                // T-bit driven/sampled after byte 1 (MDB)
  bit [7:0]         ibi_extra_data_sent[];  // extra bytes actually driven/sampled
  bit               ibi_extra_t_bits[];     // T-bit driven/sampled after each entry above (last is 0)

  constraint readDataSizeMax_c {
    soft readData.size() == MAXIMUM_BYTES;
  }
  constraint targetAddressStatus_c {
    targetAddressStatus dist {
      ACK  := 40,
      NACK := 60
    };
  }
  constraint writeDataStatusSize_c {
    soft writeDataStatus.size() == MAXIMUM_BYTES;
  }
  constraint writeDataStatusValue_c {
    foreach(writeDataStatus[i])
      soft writeDataStatus[i] == ACK;
  }
  constraint txn_type_default_c {
    soft txn_type == SDR;
  }
  constraint hotjoin_addr_default_c {
    soft hotjoin_addr == 7'h02;
  }
  constraint ibi_mdb_default_c {
    soft ibi_mdb == 8'h17;
  }

  constraint ibi_num_extra_bytes_default_c {
    soft ibi_num_extra_bytes == 0;
  }
  constraint ibi_num_extra_bytes_range_c {
    ibi_num_extra_bytes inside {[0:4]};
  }
  constraint ibi_extra_data_size_c {
    ibi_extra_data.size() == ibi_num_extra_bytes;
  }

  constraint pid_valid_c {
    if(txn_type == DAA)
      pid != 48'h0;
  }
  constraint bcr_valid_c {
    if(txn_type == DAA)
      bcr[7] == 1'b0;
  }
  extern function new(string name = "i3c_target_tx");
  extern function void do_copy(uvm_object rhs);
  extern function bit  do_compare(uvm_object rhs,
                                  uvm_comparer comparer);
  extern function void do_print(uvm_printer printer);
  extern function bit[1:0] getWriteDataStatus();
  extern function bit[1:0] getReadDataStatus();
endclass : i3c_target_tx
function i3c_target_tx::new(string name = "i3c_target_tx");
  super.new(name);
endfunction : new
function void i3c_target_tx::do_copy(uvm_object rhs);
  i3c_target_tx target_rhs;
  if(!$cast(target_rhs, rhs))
    `uvm_fatal("do_copy", "cast of rhs object failed")
  super.do_copy(rhs);
  targetAddress       = target_rhs.targetAddress;
  targetAddressStatus = target_rhs.targetAddressStatus;
  operation           = target_rhs.operation;
  writeData           = target_rhs.writeData;
  writeDataStatus     = target_rhs.writeDataStatus;
  readData            = target_rhs.readData;
  readDataStatus      = target_rhs.readDataStatus;
  txn_type        = target_rhs.txn_type;
  pid             = target_rhs.pid;
  bcr             = target_rhs.bcr;
  dcr             = target_rhs.dcr;
  dynamic_address = target_rhs.dynamic_address;
  daa_ack         = target_rhs.daa_ack;
  hotjoin_addr    = target_rhs.hotjoin_addr;
  ibi_mdb         = target_rhs.ibi_mdb;
  hdr_data        = target_rhs.hdr_data;
  hdr_crc         = target_rhs.hdr_crc;
  hdr_parity      = target_rhs.hdr_parity;
  hdr_tbit        = target_rhs.hdr_tbit;

  // --- IBI T-bit / N extra data bytes ---
  ibi_num_extra_bytes = target_rhs.ibi_num_extra_bytes;
  ibi_extra_data       = target_rhs.ibi_extra_data;
  ibi_t1               = target_rhs.ibi_t1;
  ibi_extra_data_sent  = target_rhs.ibi_extra_data_sent;
  ibi_extra_t_bits     = target_rhs.ibi_extra_t_bits;
endfunction : do_copy
function bit i3c_target_tx::do_compare(uvm_object rhs,
                                        uvm_comparer comparer);
  i3c_target_tx target_rhs;
  if(!$cast(target_rhs, rhs)) begin
    `uvm_fatal("FATAL_DO_COMPARE_FAILED", "cast of rhs object failed")
    return 0;
  end
  return super.do_compare(rhs, comparer)        &&
    targetAddress       == target_rhs.targetAddress       &&
    targetAddressStatus == target_rhs.targetAddressStatus &&
    operation           == target_rhs.operation           &&
    writeData           == target_rhs.writeData           &&
    writeDataStatus     == target_rhs.writeDataStatus     &&
    readData            == target_rhs.readData            &&
    readDataStatus      == target_rhs.readDataStatus      &&
    txn_type        == target_rhs.txn_type        &&
    pid             == target_rhs.pid             &&
    bcr             == target_rhs.bcr             &&
    dcr             == target_rhs.dcr             &&
    dynamic_address == target_rhs.dynamic_address &&
    daa_ack         == target_rhs.daa_ack         &&
    hotjoin_addr    == target_rhs.hotjoin_addr    &&
    ibi_mdb         == target_rhs.ibi_mdb         &&
    hdr_data        == target_rhs.hdr_data        &&
    hdr_crc         == target_rhs.hdr_crc         &&
    hdr_parity      == target_rhs.hdr_parity      &&
    hdr_tbit        == target_rhs.hdr_tbit        &&
    ibi_num_extra_bytes == target_rhs.ibi_num_extra_bytes &&
    ibi_extra_data       == target_rhs.ibi_extra_data       &&
    ibi_t1                == target_rhs.ibi_t1                &&
    ibi_extra_data_sent   == target_rhs.ibi_extra_data_sent   &&
    ibi_extra_t_bits      == target_rhs.ibi_extra_t_bits;
endfunction : do_compare
function void i3c_target_tx::do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_string("txn_type", txn_type.name());
  if(txn_type == SDR) begin
    printer.print_field("targetAddress",
      this.targetAddress, $bits(targetAddress), UVM_HEX);
    printer.print_string("targetAddressStatus",
      targetAddressStatus.name());
    printer.print_string("operation", operation.name());
    if(operation == I3C_WRITE) begin
      foreach(writeData[i])
        printer.print_field($sformatf("writeData[%0d]", i),
          this.writeData[i], $bits(writeData[i]), UVM_HEX);
      foreach(writeDataStatus[i])
        printer.print_string($sformatf("writeDataStatus[%0d]", i),
          writeDataStatus[i].name());
    end else begin
      foreach(readData[i])
        printer.print_field($sformatf("readData[%0d]", i),
          this.readData[i], $bits(readData[i]), UVM_HEX);
      foreach(readDataStatus[i])
        printer.print_string($sformatf("readDataStatus[%0d]", i),
          readDataStatus[i].name());
    end
  end else begin
    printer.print_field("pid",
      this.pid, $bits(pid), UVM_HEX);
    printer.print_field("bcr",
      this.bcr, $bits(bcr), UVM_HEX);
    printer.print_field("dcr",
      this.dcr, $bits(dcr), UVM_HEX);
    printer.print_field("dynamic_address",
      this.dynamic_address, $bits(dynamic_address), UVM_HEX);
    printer.print_field("daa_ack",
      this.daa_ack, 1, UVM_BIN);
    if (txn_type == HOTJOIN)
      printer.print_field("hotjoin_addr",
        this.hotjoin_addr, $bits(hotjoin_addr), UVM_HEX);
    if (txn_type == HDR_WRITE || txn_type == HDR_READ) begin
      foreach(writeData[i])
        printer.print_field($sformatf("hdr_writeData[%0d]", i),
          this.writeData[i], $bits(writeData[i]), UVM_HEX);
      foreach(readData[i])
        printer.print_field($sformatf("hdr_readData[%0d]", i),
          this.readData[i], $bits(readData[i]), UVM_HEX);
    end
    if (txn_type == IBI) begin
      printer.print_field("ibi_mdb",
        this.ibi_mdb, $bits(ibi_mdb), UVM_HEX);
      printer.print_field("ibi_num_extra_bytes",
        this.ibi_num_extra_bytes, 32, UVM_DEC);
      printer.print_field("ibi_t1",
        this.ibi_t1, 1, UVM_BIN);
      foreach (ibi_extra_data_sent[i]) begin
        printer.print_field($sformatf("ibi_extra_data_sent[%0d]", i),
          this.ibi_extra_data_sent[i], $bits(ibi_extra_data_sent[i]), UVM_HEX);
        printer.print_field($sformatf("ibi_extra_t_bits[%0d]", i),
          this.ibi_extra_t_bits[i], 1, UVM_BIN);
      end
    end
  end
endfunction : do_print
function bit[1:0] i3c_target_tx::getWriteDataStatus();
  int counterAckReceived;
  int counterNAckReceived;
  bit ack_value;
  bit nack_value;
  foreach(writeDataStatus[i]) begin
    if(writeDataStatus[i] == ACK)  counterAckReceived++;
    if(writeDataStatus[i] == NACK) counterNAckReceived++;
  end
  ack_value  = counterAckReceived  > 0 ? ACK  : NACK;
  nack_value = counterNAckReceived > 0 ? NACK : ACK;
  return ({ack_value, nack_value});
endfunction : getWriteDataStatus
function bit[1:0] i3c_target_tx::getReadDataStatus();
  int counterAckReceived;
  int counterNAckReceived;
  bit ack_value;
  bit nack_value;
  foreach(readDataStatus[i]) begin
    if(readDataStatus[i] == ACK)  counterAckReceived++;
    if(readDataStatus[i] == NACK) counterNAckReceived++;
  end
  ack_value  = counterAckReceived  > 0 ? ACK  : NACK;
  nack_value = counterNAckReceived > 0 ? NACK : ACK;
  return ({ack_value, nack_value});
endfunction : getReadDataStatus
`endif

