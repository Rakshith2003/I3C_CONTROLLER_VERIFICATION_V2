`ifndef I3C_RAL_VIRTUAL_SEQ_PKG_INCLUDED_
`define I3C_RAL_VIRTUAL_SEQ_PKG_INCLUDED_

package i3c_ral_virtual_seq_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import i3c_globals_pkg::*;
  import apb_global_pkg::*;
  import apb_master_pkg::*;
  import apb_master_seq_pkg::*;
  import i3c_target_pkg::*;
  import i3c_target_seq_pkg::*;
  import i3c_env_pkg::*;

  `define CCC_ENTDAA 8'h07

  // Base
  `include "top_virtual_base_seq.sv"

  // SDR virtual sequences
  `include "i3c_sdr_write_virtual_seq.sv"
  `include "i3c_sdr_read_virtual_seq.sv"
  `include "i3c_sdr_multi_write_read_virtual_seq.sv"
  `include "i3c_sdr_write_read_virtual_seq.sv"
  `include "i3c_sdr_write_read_write_read_virtual_seq.sv"
  `include "i3c_invalid_addr_write_virtual_seq.sv"
  `include "i3c_fifo_full_write_virtual_seq.sv"
  `include "i3c_ccc_coverage_virtual_seq.sv"
  `include "i3c_rdatab_ro_seq.sv"
  `include "i3c_verify_pos_ack_seq.sv"
  `include "i3c_verify_neg_ack_seq.sv"
  `include "i3c_verify_repeated_start_seq.sv"
  `include "i3c_start_stop_combination_seq.sv"
  `include "i3c_randomDataTransferWidth_vseq.sv"
  `include "i3c_random_rw_virtual_seq.sv"
  `include "i3c_multi_wdatab_seq.sv"
  `include "i3c_daa_sdr_virtual_seq.sv"
  `include "i3c_read_write_read_seq.sv"
  `include "i3c_multi_write_read_back_req.sv"
  `include "i3c_sdr_write_nack_virtual_seq.sv"
  `include "i3c_sdr_write_read_multi_transfer_len_virtual_seq.sv"
  `include "i3c_daa_diff_ccc_virtual_seq.sv"
  `include "i3c_sdr_write_virtual_seq_len_0.sv"
  `include "i3c_sdr_write_virtual_seq_len_128.sv"
  `include "i3c_sdr_write_virtual_seq_len_16.sv"
  `include "i3c_sdr_write_virtual_seq_len_16_wdata_0000.sv"
  `include "i3c_sdr_write_virtual_seq_len_16_wdata_5555.sv"
  `include "i3c_sdr_write_virtual_seq_len_16_wdata_AAAA.sv"
  `include "i3c_sdr_write_virtual_seq_len_16_wdata_FFFF.sv"
  `include "i3c_sdr_write_virtual_seq_len_17.sv"
  `include "i3c_sdr_write_virtual_seq_len_1.sv"
  `include "i3c_sdr_write_virtual_seq_len_1_wdata_0.sv"
`include "i3c_sdr_write_virtual_seq_len_1_wdata_55.sv"  
`include "i3c_sdr_write_virtual_seq_len_1_wdata_AA.sv"  
`include "i3c_sdr_write_virtual_seq_len_1_wdata_FF.sv"
`include "i3c_sdr_write_virtual_seq_wdata_00.sv"
`include "i3c_sdr_write_virtual_seq_wdata_55.sv"
`include "i3c_sdr_write_virtual_seq_wdata_AA.sv"
`include "i3c_sdr_write_virtual_seq_wdata_FF.sv"
`include "i3c_sdr_write_read_transfer_len_16_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_16_wdata_0_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_16_wdata_5555_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_16_wdata_AAAA_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_16_wdata_FFFF_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_1_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_1_wdata_0_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_1_wdata_55_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_1_wdata_AA_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_1_wdata_FF_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_3_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_4_virtual_seq.sv"
`include "i3c_sdr_write_read_transfer_len_8_virtual_seq.sv"
        // DAA virtual sequences
  `include "i3c_daa_virtual_seq.sv"
  `include "i3c_sdr_or_daa_virtual_seq.sv"
`include "i3c_hot_join_virtual_seq.sv"  //hot join seq
`include "i3c_ibi_virtual_seq.sv"
`include "i3c_hot_join_invalid_addr_virtual_seq.sv" 
`include "i3c_hdr_write_read_virtual_seq.sv"             // HDR-DDR write+read, NEW
`include "i3c_hdr_write_read_virtual_seq_len2.sv"        // HDR-DDR write+read len2, NEW
`include "i3c_hdr_write_read_virtual_seq_len3.sv"        // HDR-DDR write+read len3, NEW
`include "i3c_hdr_write_read_virtual_seq_len4.sv"        // HDR-DDR write+read len4, NEW
`include "i3c_hdr_write_read_virtual_seq_randomized.sv"  // HDR-DDR write+read randomized, NEW

//`include "i3c_ibi_t0_virtual_seq.sv"
endpackage : i3c_ral_virtual_seq_pkg

`endif


