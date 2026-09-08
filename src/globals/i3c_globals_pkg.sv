`ifndef I3C_GLOBALS_PKG_INCLUDED_
`define I3C_GLOBALS_PKG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Package : i3c_globals_pkg
// Used for storing I3C parameters, enums and structures
//--------------------------------------------------------------------------------------------
package i3c_globals_pkg;


  //------------------------------------------------------------------------------------------
  // Parameters
  //------------------------------------------------------------------------------------------

  parameter int NO_OF_CONTROLLERS = 1;

  parameter int NO_OF_TARGETS = 4;

  parameter int NO_OF_REG = 1;

  // Renamed to avoid conflict with APB DATA_WIDTH
  parameter int I3C_DATA_WIDTH = 8;

  parameter int TARGET_ADDRESS_WIDTH = 7;

  parameter int REGISTER_ADDRESS_WIDTH = 8;

  parameter int MAXIMUM_BITS = 1024;

  parameter int MAXIMUM_BYTES = MAXIMUM_BITS / I3C_DATA_WIDTH;


  //------------------------------------------------------------------------------------------
  // Target Addresses
  //------------------------------------------------------------------------------------------

  parameter TARGET0_ADDRESS = 7'b110_1000;   // 7'h68

  parameter TARGET1_ADDRESS = 7'b110_1100;   // 7'h6C

  parameter TARGET2_ADDRESS = 7'b111_1100;   // 7'h7C

  parameter TARGET3_ADDRESS = 7'b100_1100;   // 7'h4C


  //------------------------------------------------------------------------------------------
  // Tri-state buffer control
  //------------------------------------------------------------------------------------------

  parameter bit TRISTATE_BUF_ON  = 1;

  parameter bit TRISTATE_BUF_OFF = 0;


  //------------------------------------------------------------------------------------------
  // Bus timing
  //------------------------------------------------------------------------------------------

  parameter BUS_IDLE_TIME = 1;

  parameter BUS_FREE_TIME = 1;


  //------------------------------------------------------------------------------------------
  // I3C Broadcast / CCC Parameters
  //------------------------------------------------------------------------------------------

  parameter bit [6:0] I3C_BROADCAST_ADDR = 7'h7E;

  parameter bit [7:0] ENTDAA_CCC_CODE = 8'h07;

  parameter bit [7:0] BCAST_ADDR_WRITE = 8'hFC;

  parameter bit [7:0] BCAST_ADDR_READ = 8'hFD;

  parameter int DAA_ARB_BIT_COUNT = 64;

  parameter bit [6:0] DAA_FIRST_DYN_ADDR = 7'h08;


  //------------------------------------------------------------------------------------------
  // Command types
  //------------------------------------------------------------------------------------------

  parameter bit [1:0] CMD_TYPE_DAA = 2'd3;

  parameter bit [1:0] CMD_TYPE_SDR = 2'b00;

  parameter bit [1:0] CMD_TYPE_CCC = 2'b10;


  //------------------------------------------------------------------------------------------
  // Target Provisioning IDs
  //------------------------------------------------------------------------------------------

  parameter bit [47:0] TARGET0_PID = 48'h00_AABB_CC00_01;

  parameter bit [47:0] TARGET1_PID = 48'h00_AABB_CC00_02;

  parameter bit [47:0] TARGET2_PID = 48'h00_AABB_CC00_03;

  parameter bit [47:0] TARGET3_PID = 48'h00_AABB_CC00_04;

  parameter bit [47:0] TARGET4_PID = 48'h00_AABB_CC00_05;


  //------------------------------------------------------------------------------------------
  // BCR / DCR
  //------------------------------------------------------------------------------------------

  parameter bit [7:0] DEFAULT_BCR = 8'h00;

  parameter bit [7:0] TARGET0_DCR = 8'hC2;

  parameter bit [7:0] TARGET1_DCR = 8'hC3;

  parameter bit [7:0] TARGET2_DCR = 8'hC4;

  parameter bit [7:0] TARGET3_DCR = 8'hC5;

  parameter bit [7:0] TARGET4_DCR = 8'hC6;


  //------------------------------------------------------------------------------------------
  // Enum : dataTransferDirection_e
  //------------------------------------------------------------------------------------------
  typedef enum bit {
    MSB_FIRST = 1'b0,
    LSB_FIRST = 1'b1
  } dataTransferDirection_e;


  //------------------------------------------------------------------------------------------
  // Enum : hasCoverage_e
  //------------------------------------------------------------------------------------------
  typedef enum bit {
    TRUE  = 1'b1,
    FALSE = 1'b0
  } hasCoverage_e;


  //------------------------------------------------------------------------------------------
  // Enum : operationType_e
  // Used to declare I3C read/write operation
  //------------------------------------------------------------------------------------------
  typedef enum bit {
    I3C_WRITE = 1'b0,
    I3C_READ  = 1'b1
  } operationType_e;


  //------------------------------------------------------------------------------------------
  // Enum : writeReadMode_e
  //------------------------------------------------------------------------------------------
  typedef enum bit [1:0] {
    ONLY_WRITE = 2'b00,
    ONLY_READ  = 2'b01,
    WRITE_READ = 2'b10
  } writeReadMode_e;


  //------------------------------------------------------------------------------------------
  // Enum : txn_type_e
  //------------------------------------------------------------------------------------------
  typedef enum bit {
    SDR = 1'b0,
    DAA = 1'b1
  } txn_type_e;


  //------------------------------------------------------------------------------------------
  // Struct : i3c_transfer_bits_s
  //------------------------------------------------------------------------------------------
  typedef struct {

    bit [TARGET_ADDRESS_WIDTH-1:0] targetAddress;

    bit operation;

    bit targetAddressStatus;

    bit writeDataStatus[MAXIMUM_BYTES];

    bit readDataStatus[MAXIMUM_BYTES];

    bit [I3C_DATA_WIDTH-1:0] writeData[MAXIMUM_BYTES];

    bit [I3C_DATA_WIDTH-1:0] readData[MAXIMUM_BYTES];

    int no_of_i3c_bits_transfer;

    bit [REGISTER_ADDRESS_WIDTH-1:0] register_address;

    bit txn_type;

    bit [47:0] pid;

    bit [7:0] bcr;

    bit [7:0] dcr;

    bit [6:0] dynamic_address;

    bit daa_ack;


    // HDR-DDR additions - currently disabled

    // bit [6:0] hdr_ddr_cmd_code;
    // bit hdr_ddr_cmd_ack;
    // int hdr_ddr_num_words;
    // bit [4:0] hdr_ddr_crc_calc;
    // bit [4:0] hdr_ddr_crc_rcvd;
    // bit hdr_ddr_crc_ok;
    // bit hdr_ddr_got_restart;
    // bit hdr_ddr_got_exit;

  } i3c_transfer_bits_s;


  //------------------------------------------------------------------------------------------
  // Struct : i3c_transfer_cfg_s
  //------------------------------------------------------------------------------------------
  typedef struct {

    dataTransferDirection_e dataTransferDirection;

    bit operation;

    int clockRateDividerValue;

    bit [TARGET_ADDRESS_WIDTH-1:0] targetAddress;

    bit [I3C_DATA_WIDTH-1:0] defaultReadData;

    bit [47:0] pid;

    bit [7:0] bcr;

    bit [7:0] dcr;

    bit daa_accept_address;

  } i3c_transfer_cfg_s;


  //------------------------------------------------------------------------------------------
  // Enum : i3c_fsm_state_e
  // I3C controller FSM states
  //------------------------------------------------------------------------------------------
  typedef enum int {

    I3C_RESET_DEACTIVATED,

    I3C_RESET_ACTIVATED,

    I3C_IDLE,

    I3C_FREE,

    I3C_START,

    I3C_ADDRESS,

    I3C_WR_BIT,

    I3C_ACK_NACK,

    I3C_WRITE_DATA,

    I3C_READ_DATA,

    I3C_STOP

  } i3c_fsm_state_e;


  //------------------------------------------------------------------------------------------
  // Enum : daa_fsm_state_e
  // DAA FSM states
  //------------------------------------------------------------------------------------------
  typedef enum bit [3:0] {

    DAA_IDLE      = 4'd0,

    DAA_SEND_7E_W = 4'd1,

    DAA_ENTDAA    = 4'd2,

    DAA_REP_START = 4'd3,

    DAA_SEND_7E_R = 4'd4,

    DAA_ARB_BITS  = 4'd5,

    DAA_ASSIGN    = 4'd6,

    DAA_LOOP      = 4'd7,

    DAA_STOP      = 4'd8

  } daa_fsm_state_e;


  //------------------------------------------------------------------------------------------
  // Enum : edge_detect_e
  //------------------------------------------------------------------------------------------
  typedef enum bit [1:0] {

    POSEDGE = 2'b01,

    NEGEDGE = 2'b10

  } edge_detect_e;


  //------------------------------------------------------------------------------------------
  // Enum : acknowledge_e
  //------------------------------------------------------------------------------------------
  typedef enum bit {

    ACK  = 1'b0,

    NACK = 1'b1

  } acknowledge_e;


  /*
    HDR-DDR definitions can be enabled here when required.

    parameter bit [7:0] ENTHDR0_CCC_CODE = 8'h20;
    parameter bit [3:0] HDR_DDR_CRC_TOKEN = 4'hC;
    parameter bit [4:0] HDR_DDR_CRC5_INIT = 5'h1F;

    parameter bit [1:0] HDR_DDR_PRE_CMD_OR_CRC = 2'b01;
    parameter bit [1:0] HDR_DDR_PRE_ACCEPT_LOW = 2'b10;
    parameter bit [1:0] HDR_DDR_PRE_REJECT_HI = 2'b11;

    typedef enum bit [1:0] {
      HDR_DDR_WORD_COMMAND  = 2'b00,
      HDR_DDR_WORD_DATA     = 2'b01,
      HDR_DDR_WORD_CRC      = 2'b10,
      HDR_DDR_WORD_RESERVED = 2'b11
    } hdr_ddr_word_type_e;
  */


endpackage : i3c_globals_pkg

`endif
