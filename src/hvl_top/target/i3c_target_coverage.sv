`ifndef I3C_TARGET_COVERAGE_INCLUDED_
`define I3C_TARGET_COVERAGE_INCLUDED_
class i3c_target_coverage extends uvm_subscriber#(i3c_target_tx);
  `uvm_component_utils(i3c_target_coverage)
  //SDR Covergroup
  covergroup target_covergroup with function sample(i3c_target_tx packet);
    option.per_instance = 1;
    OPERATION_CP : coverpoint packet.operation {
      option.comment = "Operation";
      bins OPERATION_WRITE = {0};
      bins OPERATION_READ  = {1};
    }
    TARGET_ADDRESS_CP : coverpoint packet.targetAddress {
      option.comment    = "TargetAddress";
      bins TARGETADDRESS         = {[8:119]};
      illegal_bins RESERVEDADDRESS = {[0:7], [120:127]};
    }
    TARGET_ADDRESS_STATUS_CP : coverpoint packet.targetAddressStatus {
      option.comment = "targetAddressStatus";
      bins TARGET_ADDRESS_STATUS_ACK  = {0};
      bins TARGET_ADDRESS_STATUS_NACK = {1};
    }
    WRITEDATA_CP : coverpoint packet.writeData.size() * I3C_DATA_WIDTH {
      option.comment = "writeData size of the packet transfer";
      bins WRITEDATA_WIDTH_1 = {8};
      bins WRITEDATA_WIDTH_2 = {16};
      bins WRITEDATA_WIDTH_3 = {24};
      bins WRITEDATA_WIDTH_4 = {32};
      bins WRITEDATA_WIDTH_5 = {64};
      bins WRITEDATA_WIDTH_6 = {[72:MAXIMUM_BITS]};
    }
    READDATA_CP : coverpoint packet.readData.size() * I3C_DATA_WIDTH {
      option.comment = "readData size of the packet transfer";
      bins READDATA_WIDTH_1 = {8};
      bins READDATA_WIDTH_2 = {16};
      bins READDATA_WIDTH_3 = {24};
      bins READDATA_WIDTH_4 = {32};
      bins READDATA_WIDTH_5 = {64};
      bins READDATA_WIDTH_6 = {[72:MAXIMUM_BITS]};
    }
    
    WRITEDATA_STATUS_CP : coverpoint packet.getWriteDataStatus() {
      option.comment = "writeData status";
      bins WRITEDATA_STATUS_ALL_ACK  = {2'b00};
      bins WRITEDATA_STATUS_ALL_NACK = {2'b11};
      bins WRITEDATA_STATUS_MIX      = {2'b01, 2'b10};
    }
   
    READDATA_STATUS_CP : coverpoint packet.getReadDataStatus() {
      option.comment = "readData status";
      bins READDATA_STATUS_ALL_ACK  = {2'b00};
      bins READDATA_STATUS_ALL_NACK = {2'b11};
      bins READDATA_STATUS_MIX      = {2'b01, 2'b10};
    }
OPERATION_CP_X_READDATA_CP : cross OPERATION_CP, READDATA_CP {
  ignore_bins invalid_write =
    binsof(OPERATION_CP) intersect {0};
}
endgroup : target_covergroup
  covergroup daa_covergroup with function sample(i3c_target_tx packet);
    option.per_instance = 1;
    DAA_ACK_CP : coverpoint packet.daa_ack {
      option.comment = "DAA address assignment ACK/NACK";
      bins DAA_ACK  = {0};
      ignore_bins DAA_NACK = {1};
  }
    DAA_DYNADDR_CP : coverpoint packet.dynamic_address {
      option.comment = "Dynamic address assigned by controller";
      bins DYNADDR_BIN    = {[8:119]};
      illegal_bins DYNADDR_RESERVED = {[0:7], [120:127]};
    }
    DAA_PID_TOP_BYTE_CP : coverpoint packet.pid[47:40] {
      option.comment = "PID top byte (manufacturer ID upper)";
      bins PID_NONZERO = {[1:255]};
      bins PID_ZERO    = {0};
    }
    DAA_BCR_ROLE_CP : coverpoint packet.bcr[7] {
      option.comment = "BCR[7]: 0=target 1=controller";
      bins TARGET_ROLE     = {0};
      ignore_bins CONTROLLER_ROLE = {1};
    }
    DAA_DCR_CP : coverpoint packet.dcr {
      option.comment = "DCR full byte";
      bins DCR_BIN = {[0:255]};
    }
    DAA_DYNADDR_X_ACK : cross DAA_DYNADDR_CP, DAA_ACK_CP;
  endgroup : daa_covergroup
  // IBI (In-Band Interrupt) covergroup 
  covergroup ibi_covergroup with function sample(i3c_target_tx packet);
    option.per_instance = 1;
    IBI_ACK_CP : coverpoint packet.daa_ack {
      option.comment = "IBI request ACK/NACK";
      bins IBI_ACK  = {0};
      ignore_bins IBI_NACK = {1};
    }
    IBI_MDB_CP : coverpoint packet.ibi_mdb {
      option.comment = "IBI Mandatory Data Byte";
      bins IBI_MDB_BIN = {[0:255]};
    }
    
    IBI_T1_CP : coverpoint packet.ibi_t1 {
      option.comment = "T-bit after MDB: 1=more data follows, 0=STOP";
      bins T1_MORE_DATA = {1};
      bins T1_STOP      = {0};
    }
    
    IBI_NUM_EXTRA_BYTES_CP : coverpoint packet.ibi_extra_data_sent.size() {
      option.comment = "Number of IBI extra data bytes sent beyond the MDB";
      bins ZERO_EXTRA        = {0};
      bins ONE_EXTRA         = {1};
      bins TWO_EXTRA         = {2};
      bins THREE_OR_MORE_EXTRA = {[3:$]};
    }
    IBI_T1_X_NUM_EXTRA : cross IBI_T1_CP, IBI_NUM_EXTRA_BYTES_CP;
  endgroup : ibi_covergroup
  ////////////////////////HDR
  covergroup hdr_covergroup with function sample(i3c_target_tx packet);
    option.per_instance = 1;

    HDR_OPERATION_CP : coverpoint packet.operation {
      option.comment = "HDR Operation";
      bins HDR_OPERATION_WRITE = {0};
      bins HDR_OPERATION_READ  = {1};
    }

    HDR_TARGET_ADDRESS_CP : coverpoint packet.targetAddress {
      option.comment    = "HDR TargetAddress";
      bins HDR_TARGETADDRESS          = {[8:119]};
      illegal_bins HDR_RESERVEDADDRESS = {[0:7], [120:127]};
    }

    HDR_TARGET_ADDRESS_STATUS_CP : coverpoint packet.targetAddressStatus {
      option.comment = "HDR targetAddressStatus";
      bins HDR_TARGET_ADDRESS_STATUS_ACK  = {0};
      bins HDR_TARGET_ADDRESS_STATUS_NACK = {1};
    }

    HDR_WRITEDATA_CP : coverpoint packet.writeData.size() * I3C_DATA_WIDTH {
      option.comment = "HDR writeData size of the packet transfer";
      bins HDR_WRITEDATA_WIDTH_1 = {16};
      bins HDR_WRITEDATA_WIDTH_2 = {32};
      bins HDR_WRITEDATA_WIDTH_3 = {48};
      bins HDR_WRITEDATA_WIDTH_4 = {64};
      bins HDR_WRITEDATA_WIDTH_5 = {[72:MAXIMUM_BITS]};
    }

    HDR_READDATA_CP : coverpoint packet.readData.size() * I3C_DATA_WIDTH {
      option.comment = "HDR readData size of the packet transfer";
      bins HDR_READDATA_WIDTH_1 = {16};
      bins HDR_READDATA_WIDTH_2 = {32};
      bins HDR_READDATA_WIDTH_3 = {48};
      bins HDR_READDATA_WIDTH_4 = {64};
      bins HDR_READDATA_WIDTH_5 = {[72:MAXIMUM_BITS]};
    }

    HDR_WRITEDATA_STATUS_CP : coverpoint packet.getWriteDataStatus() {
      option.comment = "HDR writeData status";
      bins HDR_WRITEDATA_STATUS_ALL_ACK  = {2'b00};
      bins HDR_WRITEDATA_STATUS_ALL_NACK = {2'b11};
      bins HDR_WRITEDATA_STATUS_MIX      = {2'b01, 2'b10};
    }

    HDR_READDATA_STATUS_CP : coverpoint packet.getReadDataStatus() {
      option.comment = "HDR readData status";
      bins HDR_READDATA_STATUS_ALL_ACK  = {2'b00};
      bins HDR_READDATA_STATUS_ALL_NACK = {2'b11};
      bins HDR_READDATA_STATUS_MIX      = {2'b01, 2'b10};
    }

    HDR_OPERATION_CP_X_HDR_READDATA_CP : cross HDR_OPERATION_CP, HDR_READDATA_CP {
      ignore_bins invalid_write =
        binsof(HDR_OPERATION_CP) intersect {0};
    }
  endgroup : hdr_covergroup
  extern function new(string name = "i3c_target_coverage",
                      uvm_component parent = null);
  extern virtual function void display();
  extern virtual function void write(i3c_target_tx t);
  extern virtual function void report_phase(uvm_phase phase);
endclass : i3c_target_coverage
function i3c_target_coverage::new(
  string name = "i3c_target_coverage",
  uvm_component parent = null);
  super.new(name, parent);
  target_covergroup = new();
  daa_covergroup    = new();
  ibi_covergroup    = new();
  hdr_covergroup    = new();
endfunction : new
function void i3c_target_coverage::display();
  $display("");
  $display("--------------------------------------");
  $display("target COVERAGE");
  $display("--------------------------------------");
  $display("");
endfunction : display
function void i3c_target_coverage::write(i3c_target_tx t);
  `uvm_info("DEBUG_m_coverage",
    $sformatf("I3C_target_TX %0p", t), UVM_NONE);
  case(t.txn_type)
    i3c_target_tx::SDR: begin
      if(t.targetAddress inside {[8:119]}) begin
        target_covergroup.sample(t);
      end else begin
        `uvm_info("DEBUG_m_coverage",
          $sformatf("SDR: skipping coverage sample for reserved/broadcast addr=0x%0x",
                    t.targetAddress), UVM_HIGH)
      end
    end
    i3c_target_tx::DAA: begin
      daa_covergroup.sample(t);
    end
    i3c_target_tx::HOTJOIN: begin
      daa_covergroup.sample(t);
    end
    i3c_target_tx::IBI: begin
      ibi_covergroup.sample(t);
    end
    i3c_target_tx::HDR_WRITE, i3c_target_tx::HDR_READ: begin
      hdr_covergroup.sample(t);
    end
    default: begin
      `uvm_warning("DEBUG_m_coverage",
        $sformatf("Unknown txn_type=%0s \u2014 not sampled", t.txn_type.name()))
    end
  endcase
endfunction: write
function void i3c_target_coverage::report_phase(uvm_phase phase);
  display();
  `uvm_info(get_type_name(),
    $sformatf("target Agent SDR Coverage = %0.2f %%",
              target_covergroup.get_coverage()), UVM_NONE)
  `uvm_info(get_type_name(),
    $sformatf("target Agent DAA Coverage = %0.2f %%",
              daa_covergroup.get_coverage()), UVM_NONE)
  `uvm_info(get_type_name(),
    $sformatf("target Agent IBI Coverage = %0.2f %%",
              ibi_covergroup.get_coverage()), UVM_NONE)
  `uvm_info(get_type_name(),
    $sformatf("target Agent HDR-DDR Coverage = %0.2f %%",
              hdr_covergroup.get_coverage()), UVM_NONE)
  `uvm_info(get_type_name(),
    $sformatf("target Agent Total Coverage = %0.2f %%",
              (target_covergroup.get_coverage() +
               daa_covergroup.get_coverage()) / 2.0), UVM_NONE)
endfunction: report_phase
`endif

