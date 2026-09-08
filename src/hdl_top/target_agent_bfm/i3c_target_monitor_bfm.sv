`ifndef I3C_TARGET_MONITOR_BFM_INCLUDED_
`define I3C_TARGET_MONITOR_BFM_INCLUDED_

interface i3c_target_monitor_bfm (
  input pclk,
  input areset,
  input scl_i,
  input scl_o,
  input scl_oen,
  input sda_i,
  input sda_o,
  input sda_oen
);

  // Package imports are kept inside the interface
  // to avoid $unit wildcard-import conflicts.
  import i3c_globals_pkg::*;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import i3c_target_pkg::*;
  import i3c_target_pkg::i3c_target_monitor_proxy;

  i3c_target_monitor_proxy i3c_target_mon_proxy_h;

  i3c_fsm_state_e state;

  string name = "I3C_TARGET_MONITOR_BFM";

  localparam logic [7:0] BCAST_7E_W  = 8'hFC;
  localparam logic [7:0] ENTDAA_CODE = 8'h07;
  localparam logic [7:0] BCAST_7E_R  = 8'hFD;
  localparam int         ARB_BIT_CNT = 64;


  //--------------------------------------------------------------------------
  // Initial
  //--------------------------------------------------------------------------

  initial begin
    $display(name);
  end


  //--------------------------------------------------------------------------
  // Reset / Idle
  //--------------------------------------------------------------------------

  task wait_for_reset();
    @(negedge areset);
    @(posedge areset);
  endtask : wait_for_reset


  task sample_idle_state();
    @(posedge pclk);
  endtask : sample_idle_state


  task wait_for_idle_state();
    @(posedge pclk);

    while (scl_i != 1 && sda_i != 1)
      @(posedge pclk);

    state = I3C_IDLE;

  endtask : wait_for_idle_state


  //--------------------------------------------------------------------------
  // Normal SDR transaction sampling
  //--------------------------------------------------------------------------

  task sample_data(
    inout i3c_transfer_bits_s pkt,
    inout i3c_transfer_cfg_s  cfg
  );

    detect_start();

    sample_target_address(pkt);

    sample_operation(pkt.operation);

    sampleAddressAck(pkt.targetAddressStatus);


    if (pkt.targetAddressStatus == ACK) begin

      if (pkt.operation == I3C_WRITE)
        sampleWriteDataAndAck(pkt, cfg);

      else begin
        sampleReadDataAndAck(pkt, cfg);
      end

    end
    else begin
      detect_stop();
    end

  endtask : sample_data


  //--------------------------------------------------------------------------
  // SDR WRITE
  //--------------------------------------------------------------------------

  task sampleWriteDataAndAck(
    inout i3c_transfer_bits_s pkt,
    inout i3c_transfer_cfg_s  cfg
  );

    bit parity_received;
    bit parity_expected;
    bit stop_seen;

    stop_seen = 0;

    for (int i = 0; i < MAXIMUM_BYTES; i++) begin

      if (i == 0) begin

        // Byte 0: entry point is bit[7] POSEDGE,
        // no preceding parity edge.
        sample_write_data(cfg, pkt, i);

      end
      else begin

        // Bytes 1+: launched from the safe SCL-low
        // window left by the previous byte parity NEGEDGE.

        fork

          begin : stop_check
            wrDetect_stop();
            stop_seen = 1;
          end : stop_check

          begin : next_byte
            sample_write_data(cfg, pkt, i);
          end : next_byte

        join_any

        disable fork;

        if (stop_seen) begin

          `uvm_info(
            name,
            $sformatf(
              "SDR WRITE MON: STOP detected after byte[%0d] transfer complete",
              i-1
            ),
            UVM_NONE
          )

          break;

        end

      end


      `uvm_info(
        name,
        $sformatf(
          "SDR WRITE MON: byte[%0d] = 0x%02h (%08b)",
          i,
          pkt.writeData[i],
          pkt.writeData[i]
        ),
        UVM_NONE
      )


      // Parity POSEDGE (9th clock)
      detectEdge_scl(POSEDGE);

      parity_received = sda_i;

      parity_expected = ^pkt.writeData[i];


      // Parity trailing NEGEDGE:
      // SCL falls LOW -- safe window for
      // fork at the top of the next iteration.
      detectEdge_scl(NEGEDGE);


      `uvm_info(
        name,
        $sformatf(
          "SDR WRITE MON: byte[%0d]=0x%02h parity_rx=%0b ^data(exp)=%0b %s",
          i,
          pkt.writeData[i],
          parity_received,
          parity_expected,
          (parity_received == parity_expected)
            ? "PARITY OK"
            : "PARITY MISMATCH"
        ),
        UVM_NONE
      )


      pkt.writeDataStatus[i] = ACK;

    end


    if (!stop_seen) begin

      `uvm_info(
        name,
        "SDR WRITE MON: all bytes sampled, waiting for STOP",
        UVM_NONE
      )

      wrDetect_stop();

    end

  endtask : sampleWriteDataAndAck


  //--------------------------------------------------------------------------
  // SDR READ
  //--------------------------------------------------------------------------

  task sampleReadDataAndAck(
    inout i3c_transfer_bits_s pkt,
    inout i3c_transfer_cfg_s  cfg
  );

    bit tbit;
    int total_bytes;

    total_bytes = 0;


    for (int i = 0; i < MAXIMUM_BYTES; i++) begin

      sample_read_data(
        pkt,
        i,
        cfg.dataTransferDirection
      );

      total_bytes++;


      `uvm_info(
        name,
        $sformatf(
          "SDR READ MON: sampled byte[%0d]=0x%02h (%08b)",
          i,
          pkt.readData[i],
          pkt.readData[i]
        ),
        UVM_NONE
      )


      // 9th bit:
      // Controller-driven T-bit -- monitor just samples.
      detectEdge_scl(POSEDGE);

      tbit = sda_i;


      `uvm_info(
        name,
        $sformatf(
          "SDR READ MON: sampled controller T-bit=%0b (%s) after byte[%0d]",
          tbit,
          tbit ? "CONTINUE" : "TERMINATE",
          i
        ),
        UVM_NONE
      )


      pkt.readDataStatus[i] = tbit ? ACK : NACK;


      if (!tbit) begin

        `uvm_info(
          name,
          $sformatf(
            "SDR READ MON: stopping after byte[%0d], waiting for STOP",
            i
          ),
          UVM_NONE
        )

        break;

      end

    end


    `uvm_info(
      name,
      $sformatf(
        "SDR READ MON: sampled %0d byte(s), waiting for STOP",
        total_bytes
      ),
      UVM_NONE
    )


    wrDetect_stop();

  endtask : sampleReadDataAndAck


  //--------------------------------------------------------------------------
  // Addressed flag
  //--------------------------------------------------------------------------

  bit has_address = 0;


  function bit is_addressed();
    return has_address;
  endfunction : is_addressed


  //--------------------------------------------------------------------------
  // DAA
  //--------------------------------------------------------------------------

  task sample_daa_data(
    inout i3c_transfer_bits_s pkt,
    inout i3c_transfer_cfg_s  cfg
  );

    bit [63:0] arb_shift;
    bit [7:0]  dyn_byte;
    bit [47:0] round_pid;
    bit [7:0]  round_bcr;
    bit [7:0]  round_dcr;

    bit [1:0] scl_loc;
    bit [1:0] sda_loc;

    bit got_rep_start;

    int round;


    // Default: not assigned
    pkt.pid             = cfg.pid;
    pkt.bcr             = cfg.bcr;
    pkt.dcr             = cfg.dcr;
    pkt.daa_ack         = NACK;
    pkt.dynamic_address = 7'h00;

    round = 0;


    //--------------------------------------------------------------------------
    // Steps 1-3:
    // START + 7E+W + ENTDAA
    // Common preamble, once only.
    //--------------------------------------------------------------------------

    detect_start();

    `uvm_info(
      name,
      "DAA MON: START detected",
      UVM_HIGH
    )


    if (has_address) begin

      `uvm_info(
        name,
        "DAA MON: already has dynamic address - passively skipping this DAA session",
        UVM_NONE
      )

      skip_daa_session_passively();

      return;

    end


    //--------------------------------------------------------------------------
    // Consume 7E+W byte (8 POSEDGEs) + ACK slot
    //--------------------------------------------------------------------------

    for (int k = 7; k >= 0; k--)
      detectEdge_scl(POSEDGE);

    detectEdge_scl(NEGEDGE);
    detectEdge_scl(POSEDGE);   // ACK
    detectEdge_scl(NEGEDGE);


    //--------------------------------------------------------------------------
    // Consume ENTDAA byte (8 POSEDGEs) + ACK slot
    //--------------------------------------------------------------------------

    for (int k = 7; k >= 0; k--)
      detectEdge_scl(POSEDGE);

    detectEdge_scl(NEGEDGE);
    detectEdge_scl(POSEDGE);   // ACK
    detectEdge_scl(NEGEDGE);


    //--------------------------------------------------------------------------
    // Steps 4-11:
    // Loop per round until STOP.
    //--------------------------------------------------------------------------

    // Detect first Rep-START
    detect_rep_start(
      scl_loc,
      sda_loc
    );


    `uvm_info(
      name,
      "DAA MON: initial Rep-START detected",
      UVM_HIGH
    )


    forever begin

      round++;


      `uvm_info(
        name,
        $sformatf(
          "DAA MON: starting round %0d",
          round
        ),
        UVM_HIGH
      )


      //--------------------------------------------------------------------------
      // Step 5:
      // Consume 7E+R byte
      // Need NEGEDGE first after Rep-START.
      //--------------------------------------------------------------------------

      detectEdge_scl(NEGEDGE);

      for (int k = 7; k >= 0; k--)
        detectEdge_scl(POSEDGE);

      detectEdge_scl(NEGEDGE);
      detectEdge_scl(POSEDGE);   // ACK
      detectEdge_scl(NEGEDGE);


      //--------------------------------------------------------------------------
      // Steps 6-7:
      // Sample 64 arbitration bits.
      // Bus wire-AND = winner's bits.
      //--------------------------------------------------------------------------

      arb_shift = '0;


      for (int k = 63; k >= 0; k--) begin

        detectEdge_scl(POSEDGE);

        arb_shift[k] = sda_i;

        detectEdge_scl(NEGEDGE);

      end


      round_pid = arb_shift[63:16];
      round_bcr = arb_shift[15:8];
      round_dcr = arb_shift[7:0];


      `uvm_info(
        name,
        $sformatf(
          "DAA MON [round %0d] bus winner PID=0x%0h BCR=0x%0h DCR=0x%0h | my PID=0x%0h",
          round,
          round_pid,
          round_bcr,
          round_dcr,
          cfg.pid
        ),
        UVM_NONE
      )


      //--------------------------------------------------------------------------
      // Step 9:
      // Sample dynamic address byte from master.
      //--------------------------------------------------------------------------

      for (int k = 7; k >= 0; k--) begin

        detectEdge_scl(POSEDGE);

        dyn_byte[k] = sda_i;

      end


      //--------------------------------------------------------------------------
      // Step 10:
      // Sample winner ACK.
      //--------------------------------------------------------------------------

      detectEdge_scl(NEGEDGE);
      detectEdge_scl(POSEDGE);


      // daa_ack on bus:
      // 0 = winner ACKed
      // 1 = NACK
      //
      // We read it but only store it if this round's winner
      // is our target.


      //--------------------------------------------------------------------------
      // Step 11:
      // Detect Rep-START or STOP.
      //--------------------------------------------------------------------------

      detect_rep_start_or_stop(
        scl_loc,
        sda_loc,
        got_rep_start
      );


      detectEdge_scl(NEGEDGE);


      //--------------------------------------------------------------------------
      // Does this round's winner match THIS target?
      //--------------------------------------------------------------------------

      if (
        round_pid == cfg.pid &&
        round_bcr == cfg.bcr &&
        round_dcr == cfg.dcr
      ) begin

        // This target won this round.

        pkt.pid             = cfg.pid;
        pkt.bcr             = cfg.bcr;
        pkt.dcr             = cfg.dcr;

        pkt.dynamic_address = dyn_byte[7:1];

        pkt.daa_ack         = ACK;

        has_address         = 1;


        `uvm_info(
          name,
          $sformatf(
            "DAA MON [round %0d] THIS TARGET WON: dyn_addr=0x%0h",
            round,
            pkt.dynamic_address
          ),
          UVM_NONE
        )


        return;

      end


      if (!got_rep_start) begin

        // STOP:
        // DAA complete, this target was never assigned.

        `uvm_info(
          name,
          $sformatf(
            "DAA MON: STOP detected after round %0d target not assigned (pid=0x%0h)",
            round,
            cfg.pid
          ),
          UVM_NONE
        )

        // pkt already defaulted to NACK/0.
        return;

      end


      `uvm_info(
        name,
        $sformatf(
          "DAA MON [round %0d] this target did not win, continuing to round %0d",
          round,
          round + 1
        ),
        UVM_HIGH
      )

      // Rep-START:
      // loop to next round.

    end

  endtask : sample_daa_data


  //--------------------------------------------------------------------------
  // Passive DAA monitoring
  //--------------------------------------------------------------------------

  task automatic skip_daa_session_passively();

    bit [1:0] scl_loc;
    bit [1:0] sda_loc;
    bit       got_rep_start;


    // Consume 7E+W + ACK

    for (int k = 7; k >= 0; k--)
      detectEdge_scl(POSEDGE);

    detectEdge_scl(NEGEDGE);
    detectEdge_scl(POSEDGE);
    detectEdge_scl(NEGEDGE);


    // Consume ENTDAA + ACK

    for (int k = 7; k >= 0; k--)
      detectEdge_scl(POSEDGE);

    detectEdge_scl(NEGEDGE);
    detectEdge_scl(POSEDGE);
    detectEdge_scl(NEGEDGE);


    detect_rep_start(
      scl_loc,
      sda_loc
    );


    forever begin

      detectEdge_scl(NEGEDGE);


      // 7E+R

      for (int k = 7; k >= 0; k--)
        detectEdge_scl(POSEDGE);


      // ACK

      detectEdge_scl(NEGEDGE);
      detectEdge_scl(POSEDGE);
      detectEdge_scl(NEGEDGE);


      // 64 arbitration bits

      for (int k = 63; k >= 0; k--) begin

        detectEdge_scl(POSEDGE);
        detectEdge_scl(NEGEDGE);

      end


      // Dynamic address byte

      for (int k = 7; k >= 0; k--)
        detectEdge_scl(POSEDGE);


      // ACK/NACK

      detectEdge_scl(NEGEDGE);
      detectEdge_scl(POSEDGE);


      // Rep-START or STOP

      detect_rep_start_or_stop(
        scl_loc,
        sda_loc,
        got_rep_start
      );


      detectEdge_scl(NEGEDGE);


      if (!got_rep_start)
        return;

    end

  endtask : skip_daa_session_passively


  //--------------------------------------------------------------------------
  // Detect Repeated START
  //--------------------------------------------------------------------------

  task automatic detect_rep_start(
    ref bit [1:0] scl_loc,
    ref bit [1:0] sda_loc
  );

    scl_loc = {scl_i, scl_i};
    sda_loc = {sda_i, sda_i};


    do begin

      @(negedge pclk);

      scl_loc = {scl_loc[0], scl_i};
      sda_loc = {sda_loc[0], sda_i};

    end
    while (
      !(sda_loc == 2'b10 && scl_loc == 2'b11)
    );


    `uvm_info(
      name,
      $sformatf(
        "repeated start detected @ time=%0t",
        $time
      ),
      UVM_NONE
    )

  endtask : detect_rep_start


  //--------------------------------------------------------------------------
  // Detect Repeated START or STOP
  //--------------------------------------------------------------------------

  task automatic detect_rep_start_or_stop(
    ref bit [1:0] scl_loc,
    ref bit [1:0] sda_loc,
    output bit    got_rep_start
  );

    scl_loc = {scl_i, scl_i};
    sda_loc = {sda_i, sda_i};


    forever begin

      @(negedge pclk);

      scl_loc = {scl_loc[0], scl_i};
      sda_loc = {sda_loc[0], sda_i};


      // SDA falls while SCL = 1 -> Rep-START

      if (
        scl_loc == 2'b11 &&
        sda_loc == 2'b10
      ) begin

        `uvm_info(
          name,
          $sformatf(
            "DAA repeated start detected @ time=%0t",
            $time
          ),
          UVM_NONE
        )

        got_rep_start = 1;

        return;

      end


      // SDA rises while SCL = 1 -> STOP

      if (
        scl_loc == 2'b11 &&
        sda_loc == 2'b01
      ) begin

        `uvm_info(
          name,
          "DAA MON: STOP detected",
          UVM_HIGH
        )

        got_rep_start = 0;

        return;

      end

    end

  endtask : detect_rep_start_or_stop


  //--------------------------------------------------------------------------
  // Detect START
  //--------------------------------------------------------------------------

  task detect_start();

    bit [1:0] scl_d;
    bit [1:0] sda_d;


    state = I3C_START;


    do begin

      @(negedge pclk);

      scl_d = {scl_d[0], scl_i};
      sda_d = {sda_d[0], sda_i};

    end
    while (
      !(sda_d == NEGEDGE && scl_d == 2'b11)
    );


    `uvm_info(
      name,
      $sformatf(
        "start detected @ time=%0t",
        $time
      ),
      UVM_NONE
    )

  endtask : detect_start


  //--------------------------------------------------------------------------
  // Detect STOP
  //--------------------------------------------------------------------------

  task detect_stop();

    bit [1:0] scl_d;
    bit [1:0] sda_d;


    state = I3C_STOP;


    do begin

      @(negedge pclk);

      #1;

      scl_d = {scl_d[0], scl_i};
      sda_d = {sda_d[0], sda_i};

    end
    while (
      !(sda_d == POSEDGE && scl_d == 2'b11)
    );


    `uvm_info(
      name,
      $sformatf(
        "stop detected @ time=%0t",
        $time
      ),
      UVM_NONE
    )

  endtask : detect_stop


  //--------------------------------------------------------------------------
  // Detect STOP during WRITE
  //--------------------------------------------------------------------------

  task wrDetect_stop();

    bit [1:0] scl_d;
    bit [1:0] sda_d;


    scl_d = {scl_i, scl_i};
    sda_d = {sda_i, sda_i};


    forever begin

      do begin

        @(negedge pclk);

        #1;

        scl_d = {scl_d[0], scl_i};
        sda_d = {sda_d[0], sda_i};

      end
      while (
        !(sda_d == 2'b01 && scl_d == 2'b11)
      );


      @(negedge pclk);

      #1;

      scl_d = {scl_d[0], scl_i};
      sda_d = {sda_d[0], sda_i};


      if (scl_d == 2'b10) begin

        `uvm_info(
          name,
          "wrDetect_stop MON: ignoring false STOP candidate (SCL fell = inter-byte transition)",
          UVM_HIGH
        )

        continue;

      end


      state = I3C_STOP;


      `uvm_info(
        name,
        "wrDetect_stop MON: STOP condition confirmed",
        UVM_HIGH
      )


      return;

    end

  endtask : wrDetect_stop


  //--------------------------------------------------------------------------
  // Sample Target Address
  //--------------------------------------------------------------------------

  task sample_target_address(
    inout i3c_transfer_bits_s pkt
  );

    bit [TARGET_ADDRESS_WIDTH-1:0] addr;


    state = I3C_ADDRESS;


    detectEdge_scl(NEGEDGE);


    for (
      int k = TARGET_ADDRESS_WIDTH-1;
      k >= 0;
      k--
    ) begin

      detectEdge_scl(POSEDGE);

      addr[k] = sda_i;

    end


    pkt.targetAddress = addr;

  endtask : sample_target_address


  //--------------------------------------------------------------------------
  // Sample Operation
  //--------------------------------------------------------------------------

  task sample_operation(
    output operationType_e op
  );

    bit b;


    state = I3C_WR_BIT;


    detectEdge_scl(POSEDGE);

    b = sda_i;


    op = (b == 1'b0)
         ? I3C_WRITE
         : I3C_READ;

  endtask : sample_operation


  //--------------------------------------------------------------------------
  // Sample Address ACK
  //--------------------------------------------------------------------------

  task sampleAddressAck(
    output bit ack
  );

    state = I3C_ACK_NACK;


    detectEdge_scl(NEGEDGE);

    detectEdge_scl(POSEDGE);

    ack = sda_i;

    detectEdge_scl(NEGEDGE);

  endtask : sampleAddressAck


  //--------------------------------------------------------------------------
  // Sample WRITE Data
  //--------------------------------------------------------------------------

  task sample_write_data(
    input  i3c_transfer_cfg_s  cfg,
    inout i3c_transfer_bits_s pkt,
    input int                  i
  );

    bit [I3C_DATA_WIDTH-1:0] wdata;


    state = I3C_WRITE_DATA;


    for (
      int k = 0, bit_no = 0;
      k < I3C_DATA_WIDTH;
      k++
    ) begin

      bit_no =
        (cfg.dataTransferDirection == MSB_FIRST)
        ? ((I3C_DATA_WIDTH-1) - k)
        : k;


      detectEdge_scl(POSEDGE);

      wdata[bit_no] = sda_i;

      pkt.no_of_i3c_bits_transfer++;

    end


    pkt.writeData[i] = wdata;

  endtask : sample_write_data


  //--------------------------------------------------------------------------
  // Sample WRITE Data ACK
  //--------------------------------------------------------------------------

  task sampleWdataAck(
    output bit ack
  );

    state = I3C_ACK_NACK;


    detectEdge_scl(NEGEDGE);

    detectEdge_scl(POSEDGE);

    ack = sda_i;

    detectEdge_scl(NEGEDGE);

  endtask : sampleWdataAck


  //--------------------------------------------------------------------------
  // Sample READ Data
  //--------------------------------------------------------------------------

  task sample_read_data(
    inout i3c_transfer_bits_s pkt,
    input int                  i,
    input dataTransferDirection_e dir
  );

    bit [I3C_DATA_WIDTH-1:0] rdata;


    state = I3C_READ_DATA;


    for (
      int k = 0, bit_no = 0;
      k < I3C_DATA_WIDTH;
      k++
    ) begin

      bit_no =
        (dir == MSB_FIRST)
        ? ((I3C_DATA_WIDTH-1) - k)
        : k;


      detectEdge_scl(POSEDGE);

      rdata[bit_no] = sda_i;

      pkt.no_of_i3c_bits_transfer++;

    end


    pkt.readData[i] = rdata;

  endtask : sample_read_data


  //--------------------------------------------------------------------------
  // Sample READ ACK
  //--------------------------------------------------------------------------

  task sampleReadAck(
    output bit ack
  );

    state = I3C_ACK_NACK;


    detectEdge_scl(POSEDGE);

    ack = sda_i;

    detectEdge_scl(NEGEDGE);

  endtask : sampleReadAck


  //--------------------------------------------------------------------------
  // Detect SCL Edge
  //--------------------------------------------------------------------------

  task automatic detectEdge_scl(
    input edge_detect_e edgeSCL
  );

    bit [1:0] scl_loc_m = 2'b11;


    do begin

      @(negedge pclk);

      scl_loc_m = {
        scl_loc_m[0],
        scl_i
      };

    end
    while (!(scl_loc_m == edgeSCL));

  endtask : detectEdge_scl


  //--------------------------------------------------------------------------
  // HOT JOIN monitoring
  //--------------------------------------------------------------------------

  task sample_hot_join_ibi(
    output bit [6:0] ibi_addr_out,
    output bit       ack
  );

    bit [7:0] full_byte;


    `uvm_info(
      name,
      "HOT_JOIN MON: waiting for IBI request (SDA fall while SCL high)",
      UVM_NONE
    )


    // Electrically identical pattern to an IBI request.
    detect_start();


    `uvm_info(
      name,
      "HOT_JOIN MON: sampling IBI address byte",
      UVM_NONE
    )


    detectEdge_scl(NEGEDGE);


    for (int k = 7; k >= 0; k--) begin

      detectEdge_scl(POSEDGE);

      full_byte[k] = sda_i;

    end


    ibi_addr_out = full_byte[7:1];


    // ACK slot driven by the controller
    // for this read-direction byte.

    detectEdge_scl(NEGEDGE);

    detectEdge_scl(POSEDGE);

    ack = sda_i;

    detectEdge_scl(NEGEDGE);


    `uvm_info(
      name,
      $sformatf(
        "HOT_JOIN MON: ibi_addr=0x%0h ack=%0b (controller will restart ENTDAA)",
        ibi_addr_out,
        ack
      ),
      UVM_NONE
    )

  endtask : sample_hot_join_ibi


  //--------------------------------------------------------------------------
  // HOT JOIN Data
  //--------------------------------------------------------------------------

  task sample_hot_join_data(
    inout i3c_transfer_bits_s pkt,
    inout i3c_transfer_cfg_s  cfg,
    output bit [6:0]           observed_ibi_addr
  );

    bit ack;


    sample_hot_join_ibi(
      observed_ibi_addr,
      ack
    );


    if (ack == 0) begin

      sample_daa_data(
        pkt,
        cfg
      );

    end
    else begin

      detect_stop();

    end

  endtask : sample_hot_join_data


  //--------------------------------------------------------------------------
  // IBI Request
  //--------------------------------------------------------------------------

  task sample_ibi_request(
    output bit [6:0] ibi_addr_out,
    output bit       ack_out
  );

    bit [7:0] full_byte;


    `uvm_info(
      name,
      "IBI MON: waiting for IBI request (SDA fall while SCL high)",
      UVM_NONE
    )


    detect_start();


    `uvm_info(
      name,
      "IBI MON: sampling IBI address byte",
      UVM_NONE
    )


    detectEdge_scl(NEGEDGE);


    for (int k = 7; k >= 0; k--) begin

      detectEdge_scl(POSEDGE);

      full_byte[k] = sda_i;

    end


    ibi_addr_out = full_byte[7:1];


    // ACK slot -- driven by controller
    // for this read-direction byte.

    detectEdge_scl(NEGEDGE);

    detectEdge_scl(POSEDGE);

    ack_out = sda_i;

    detectEdge_scl(NEGEDGE);


    `uvm_info(
      name,
      $sformatf(
        "IBI MON: addr=0x%0h ack=%0b",
        ibi_addr_out,
        ack_out
      ),
      UVM_NONE
    )

  endtask : sample_ibi_request


  //--------------------------------------------------------------------------
  // IBI Payload Byte
  //--------------------------------------------------------------------------

  task sample_ibi_payload_byte(
    output bit [7:0] data_out,
    output bit       t_bit_out
  );

    for (int k = 7; k >= 0; k--) begin

      detectEdge_scl(POSEDGE);

      data_out[k] = sda_i;

    end


    detectEdge_scl(NEGEDGE);

    detectEdge_scl(POSEDGE);   // T-bit slot

    t_bit_out = sda_i;

    detectEdge_scl(NEGEDGE);


    `uvm_info(
      name,
      $sformatf(
        "IBI MON: data=0x%0h T-bit=%0b (%0s)",
        data_out,
        t_bit_out,
        t_bit_out
          ? "MORE DATA"
          : "NO MORE DATA/STOP"
      ),
      UVM_NONE
    )

  endtask : sample_ibi_payload_byte


  //--------------------------------------------------------------------------
  // IBI Data
  //--------------------------------------------------------------------------

  task sample_ibi_data(
    output bit [6:0] ibi_addr_out,
    output bit       ack_out,
    output bit [7:0] mdb_out,
    output bit       t1_out,
    output bit [7:0] extra_data_out[],
    output bit       extra_t_bits_out[]
  );

    bit [7:0] extra_data_q[$];
    bit       extra_t_q[$];
    bit       more_data;


    mdb_out          = 8'h00;
    t1_out           = 1'b0;

    extra_data_out   = new[0];
    extra_t_bits_out = new[0];


    sample_ibi_request(
      ibi_addr_out,
      ack_out
    );


    if (ack_out == ACK) begin

      sample_ibi_payload_byte(
        mdb_out,
        t1_out
      );


      more_data = t1_out;


      while (more_data) begin

        bit [7:0] cur_data;
        bit       cur_t;


        `uvm_info(
          name,
          $sformatf(
            "IBI MON: T=1 sampled, sampling extra byte[%0d]",
            extra_data_q.size()
          ),
          UVM_NONE
        )


        sample_ibi_payload_byte(
          cur_data,
          cur_t
        );


        extra_data_q.push_back(cur_data);
        extra_t_q.push_back(cur_t);

        more_data = cur_t;

      end


      extra_data_out   = extra_data_q;
      extra_t_bits_out = extra_t_q;


      detect_stop();

    end
    else begin

      `uvm_info(
        name,
        "IBI MON: request NACKed, no payload phase",
        UVM_NONE
      )

    end

  endtask : sample_ibi_data


endinterface : i3c_target_monitor_bfm

`endif
