`ifndef APB_MASTER_MONITOR_BFM_INCLUDED_
`define APB_MASTER_MONITOR_BFM_INCLUDED_

//--------------------------------------------------------------------------------------------
// Interface: apb_master_monitor_bfm
//  Connects the master monitor BFM with the master monitor proxy
//--------------------------------------------------------------------------------------------
interface apb_master_monitor_bfm (
                                  input bit pclk,
                                  input bit preset_n,
                                  input bit pslverr,
                                  input bit pready,

                                  input bit [2:0] pprot,

                                  input logic penable,
                                  input logic pwrite,

                                  input logic [apb_global_pkg::ADDRESS_WIDTH-1:0] paddr,

                                  input logic [apb_global_pkg::NO_OF_SLAVES-1:0] pselx,

                                  input logic [apb_global_pkg::APB_DATA_WIDTH-1:0] pwdata,

                                  input logic [(apb_global_pkg::APB_DATA_WIDTH/8)-1:0] pstrb,

                                  input logic [apb_global_pkg::APB_DATA_WIDTH-1:0] prdata
                                 );

  //------------------------------------------------------------------------------------------
  // Importing APB global package
  //------------------------------------------------------------------------------------------
  import apb_global_pkg::*;

  //------------------------------------------------------------------------------------------
  // Importing UVM package
  //------------------------------------------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //------------------------------------------------------------------------------------------
  // Importing APB master package
  //------------------------------------------------------------------------------------------
  import apb_master_pkg::*;

  //------------------------------------------------------------------------------------------
  // Variable: apb_master_mon_proxy_h
  // Declaring handle for apb_master_monitor_proxy
  //------------------------------------------------------------------------------------------
  apb_master_monitor_proxy apb_master_mon_proxy_h;

  //------------------------------------------------------------------------------------------
  // Variable: name
  // Assigning the string used in infos
  //------------------------------------------------------------------------------------------
  string name = "APB_MASTER_MONITOR_BFM";


  //------------------------------------------------------------------------------------------
  // Initial block
  //------------------------------------------------------------------------------------------
  initial begin
    `uvm_info(
      name,
      $sformatf("APB MASTER MONITOR BFM"),
      UVM_LOW
    );
  end


  //------------------------------------------------------------------------------------------
  // Task: wait_for_preset_n
  //
  // Waiting for the system reset to be active low
  //------------------------------------------------------------------------------------------
  task wait_for_preset_n();

    @(negedge preset_n);

    `uvm_info(
      name,
      $sformatf("system reset detected"),
      UVM_HIGH
    );

    @(posedge preset_n);

    `uvm_info(
      name,
      $sformatf("system reset deactivated"),
      UVM_HIGH
    );

  endtask : wait_for_preset_n


  //------------------------------------------------------------------------------------------
  // Task: sample_data
  //
  // In this task the pwdata and prdata are sampled.
  //
  // Parameters:
  // apb_data_packet - Handle for apb_transfer_char_s class
  // apb_cfg_packet  - Handle for apb_transfer_cfg_s class
  //------------------------------------------------------------------------------------------
  task sample_data (
    output apb_transfer_char_s apb_data_packet,
    input  apb_transfer_cfg_s  apb_cfg_packet
  );

    @(negedge pclk);


    //----------------------------------------------------------------------------------------
    // Wait until a valid APB ACCESS phase is detected.
    //
    // Exactly one slave must be selected and PENABLE must be high.
    //----------------------------------------------------------------------------------------
    while (
      $countones(pselx) !== 1 ||
      penable !== 1
    ) begin

      @(negedge pclk);

    end


    //----------------------------------------------------------------------------------------
    // Wait for PREADY to become high.
    // Count the number of wait states.
    //----------------------------------------------------------------------------------------
    while (pready !== 1) begin

      `uvm_info(
        name,
        $sformatf(
          "Inside while loop: penable=%0d, pready=%0d, pselx=%0d",
          penable,
          pready,
          pselx
        ),
        UVM_HIGH
      );

      @(negedge pclk);

      // Increment the counter of wait states
      apb_data_packet.no_of_wait_states++;

    end


    //----------------------------------------------------------------------------------------
    // Sample APB transaction information
    //----------------------------------------------------------------------------------------
    apb_data_packet.pslverr = pslverr;
    apb_data_packet.pprot   = pprot;
    apb_data_packet.pwrite  = pwrite;
    apb_data_packet.paddr   = paddr;
    apb_data_packet.pselx   = pselx;
    apb_data_packet.pstrb   = pstrb;


    //----------------------------------------------------------------------------------------
    // Sample write or read data
    //----------------------------------------------------------------------------------------
    if (pwrite == APB_WRITE) begin

      apb_data_packet.pwdata = pwdata;

    end
    else begin

      apb_data_packet.prdata = prdata;

    end


    //----------------------------------------------------------------------------------------
    // Print sampled transaction
    //----------------------------------------------------------------------------------------
    `uvm_info(
      name,
      $sformatf(
        "MASTER_SAMPLE_DATA=%p",
        apb_data_packet
      ),
      UVM_HIGH
    );

  endtask : sample_data


endinterface : apb_master_monitor_bfm

`endif
