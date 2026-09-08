`ifndef I3C_TARGET_DRIVER_BFM_INCLUDED_
`define I3C_TARGET_DRIVER_BFM_INCLUDED_

interface i3c_target_driver_bfm (
  input  pclk,
  input  areset,
  input  scl_i,
  output reg scl_o,
  output reg scl_oen,
  input  sda_i,
  output reg sda_o,
  output reg sda_oen
);

  import i3c_globals_pkg::*;

  i3c_fsm_state_e state;

  bit [I3C_DATA_WIDTH-1:0] rdata;
  bit [1:0] scl_local = 2'b11;
  static int count = 0;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import i3c_target_pkg::i3c_target_driver_proxy;

  i3c_target_driver_proxy i3c_target_drv_proxy_h;

  bit [I3C_DATA_WIDTH-1:0] targetFIFOMemory[$];

  string name = "I3C_TARGET_DRIVER_BFM";

  initial begin
    $display(name);
  end


  task wait_for_system_reset();

    state = I3C_RESET_DEACTIVATED;

    @(negedge areset);

    state = I3C_RESET_ACTIVATED;

    @(posedge areset);

    state = I3C_RESET_DEACTIVATED;

  endtask : wait_for_system_reset


  task drive_idle_state();

    @(posedge pclk);

    drive_scl(1);
    drive_sda(1);

    state <= I3C_IDLE;

    `uvm_info(name, "inside idle state", UVM_HIGH)

  endtask : drive_idle_state


  task wait_for_idle_state();

    @(posedge pclk);

    while (scl_i != 1 && sda_i != 1) begin
      @(posedge pclk);
    end

    state = I3C_IDLE;

    `uvm_info(name, "I3C bus is free state detected", UVM_NONE)

  endtask : wait_for_idle_state


  task drive_data(
    inout i3c_transfer_bits_s dataPacketStruck,
    input i3c_transfer_cfg_s configPacketStruck
  );

    bit [7:0] addr_w_byte;
    bit       parity_computed;

    `uvm_info(name, "target txn started", UVM_HIGH)

    detect_start();

    sample_target_address(configPacketStruck, dataPacketStruck);

    sample_operation(dataPacketStruck.operation);

    driveAddressAck(dataPacketStruck.targetAddressStatus);

    if (dataPacketStruck.targetAddressStatus == ACK) begin

      `uvm_info(name, "targetAddressStatus is ACK", UVM_HIGH)

      if (dataPacketStruck.operation == I3C_WRITE) begin

        sampleWriteDataAndDriveACK(
          dataPacketStruck,
          configPacketStruck
        );

      end
      else begin

        driveReadDataAndSampleTbit(
          dataPacketStruck,
          configPacketStruck
        );

      end

    end
    else begin

      `uvm_info(name, "targetAddressStatus is NACK", UVM_HIGH)

      detect_stop();

    end

  endtask : drive_data


  // sampleWriteDataAndDriveACK - SDR WRITE multi-byte
  task sampleWriteDataAndDriveACK(
    inout i3c_transfer_bits_s dataPacketStruck,
    input i3c_transfer_cfg_s configPacketStruck
  );

    bit parity_received;
    bit parity_expected;
    bit stop_seen;

    `uvm_info(
      name,
      "sampleWriteDataAndDriveACK started",
      UVM_NONE
    )

    `uvm_info(
      "sdr_debug",
      $sformatf("SDR WRITE check"),
      UVM_NONE
    )

    stop_seen = 0;

    for (int i = 0; i < MAXIMUM_BYTES; i++) begin

      if (i == 0) begin

        sample_write_data(
          configPacketStruck,
          dataPacketStruck,
          i
        );

      end
      else begin

        fork

          begin : stop_check

            wrDetect_stop();

            stop_seen = 1;

          end : stop_check


          begin : next_byte

            sample_write_data(
              configPacketStruck,
              dataPacketStruck,
              i
            );

          end : next_byte

        join_any

        disable fork;

        if (stop_seen) begin

          `uvm_info(
            name,
            $sformatf(
              "SDR WRITE: STOP detected after byte[%0d] transfer complete",
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
          "SDR WRITE: byte[%0d] = 0x%02h (%08b)",
          i,
          dataPacketStruck.writeData[i],
          dataPacketStruck.writeData[i]
        ),
        UVM_NONE
      )

      `uvm_info(
        "SDR_PARITY",
        $sformatf("SDR WRITE PARITY SAMPLE"),
        UVM_NONE
      )

      detectEdge_scl(POSEDGE);

      parity_received = sda_i;

      parity_expected = ^dataPacketStruck.writeData[i];

      detectEdge_scl(NEGEDGE);

      `uvm_info(
        name,
        $sformatf(
          "SDR WRITE: byte[%0d]=0x%02h parity_rx=%0b ^data(exp)=%0b %s",
          i,
          dataPacketStruck.writeData[i],
          parity_received,
          parity_expected,
          (parity_received == parity_expected) ?
            "PARITY OK" :
            "PARITY MISMATCH"
        ),
        UVM_NONE
      )

      dataPacketStruck.writeDataStatus[i] = ACK;

    end

    if (!stop_seen) begin

      `uvm_info(
        name,
        "SDR WRITE: all bytes received, waiting for STOP",
        UVM_NONE
      )

      wrDetect_stop();

    end

    `uvm_info(
      name,
      "sampleWriteDataAndDriveACK done",
      UVM_NONE
    )

  endtask : sampleWriteDataAndDriveACK


  task driveReadDataAndSampleTbit(
    inout i3c_transfer_bits_s dataPacketStruck,
    input i3c_transfer_cfg_s configPacketStruck
  );

    bit t_bit;
    int total_bytes;

    `uvm_info(
      name,
      "driveReadDataAndSampleTbit started",
      UVM_HIGH
    )

    total_bytes = 0;

    for (int i = 0; i < MAXIMUM_BYTES; i++) begin

      if (targetFIFOMemory.size() == 0)
        rdata = configPacketStruck.defaultReadData;
      else
        rdata = targetFIFOMemory.pop_front();

      drive_read_data(
        rdata,
        dataPacketStruck,
        i,
        configPacketStruck.dataTransferDirection
      );

      total_bytes++;

      `uvm_info(
        name,
        $sformatf(
          "SDR READ: drove byte[%0d]=0x%02h (%08b)",
          i,
          rdata,
          rdata
        ),
        UVM_NONE
      )

      // The TARGET drives the T-bit, not the controller.
      // T=1 -> target has more data -> continue
      // T=0 -> target signals last byte -> end message

      t_bit = (
        targetFIFOMemory.size() > 0 &&
        (i + 1) < MAXIMUM_BYTES
      ) ? 1'b1 : 1'b0;

      drive_sda(t_bit);

      `uvm_info(
        name,
        $sformatf(
          "SDR READ: T-bit=%0b (%s) driven on SDA",
          t_bit,
          t_bit ? "MORE BYTES" : "LAST BYTE"
        ),
        UVM_NONE
      )

      `uvm_info(
        "read_sdr_t_bit",
        $sformatf("t bit=%d", t_bit),
        UVM_NONE
      )

      dataPacketStruck.readDataStatus[i] =
        t_bit ? ACK : NACK;

      if (!t_bit) begin

        `uvm_info(
          name,
          $sformatf(
            "SDR READ: T-bit=0 after byte[%0d] — last byte, waiting for STOP",
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
        "SDR READ: drove %0d byte(s), waiting for STOP",
        total_bytes
      ),
      UVM_NONE
    )

    wrDetect_stop();

    `uvm_info(
      name,
      "driveReadDataAndSampleTbit done",
      UVM_HIGH
    )

  endtask : driveReadDataAndSampleTbit


  // DAA TRANSACTION (multi-slave arbitration)

  bit has_address = 0;


  task drive_daa_data(
    inout i3c_transfer_bits_s dataPacketStruck,
    input i3c_transfer_cfg_s configPacketStruck,
    output bit [47:0] pid_out,
    output bit [7:0]  bcr_out,
    output bit [7:0]  dcr_out,
    output bit [6:0]  dyn_addr_out,
    output bit        daa_ack_out
  );

    bit [63:0] my_id;
    bit        won_arb;
    bit [6:0]  assigned_addr;
    bit [7:0]  dyn_addr_byte;
    int        lost_bit;
    bit        got_rep_start;

    `uvm_info(
      name,
      "DAA transaction started",
      UVM_NONE
    )

    if (has_address) begin

      `uvm_info(
        "HAS_ADDR",
        "Already has dynamic address - ignoring DAA",
        UVM_NONE
      )

      daa_ack_out  = NACK;
      pid_out      = configPacketStruck.pid;
      bcr_out      = configPacketStruck.bcr;
      dcr_out      = configPacketStruck.dcr;
      dyn_addr_out = 7'h00;

      return;

    end

    my_id = {
      configPacketStruck.pid,
      configPacketStruck.bcr,
      configPacketStruck.dcr
    };

    detect_start();

    `uvm_info(
      name,
      "DAA: START detected",
      UVM_NONE
    )

    sample_daa_broadcast_address(dataPacketStruck);

    sample_daa_ccc_byte(dataPacketStruck);

    detect_repeated_start();

    sample_daa_broadcast_read(dataPacketStruck);

    won_arb = 0;

    while (!won_arb) begin

      drive_daa_arb_bits(
        my_id,
        won_arb,
        lost_bit
      );

      if (!won_arb) begin

        drive_sda(1);

        `uvm_info(
          name,
          "DAA: Lost arbitration",
          UVM_NONE
        )

        skip_remaining_winner_frame(lost_bit);

        detect_rep_start_or_stop(got_rep_start);

        if (!got_rep_start) begin

          `uvm_info(
            name,
            "DAA: STOP after losing arb - DAA complete without winning",
            UVM_NONE
          )

          daa_ack_out  = NACK;
          pid_out      = configPacketStruck.pid;
          bcr_out      = configPacketStruck.bcr;
          dcr_out      = configPacketStruck.dcr;
          dyn_addr_out = 7'h00;

          return;

        end

        `uvm_info(
          name,
          "DAA: REP_START - re-entering arb with 7E+R header",
          UVM_NONE
        )

        sample_daa_broadcast_read(dataPacketStruck);

      end

    end

    sample_daa_dynamic_address(
      assigned_addr,
      dyn_addr_byte,
      daa_ack_out
    );

    driveAddressAck(daa_ack_out);

    if (daa_ack_out == ACK) begin

      has_address = 1;

      `uvm_info(
        name,
        $sformatf(
          "DAA: slave assigned dynamic address 0x%0x",
          assigned_addr
        ),
        UVM_NONE
      )

    end

    pid_out      = configPacketStruck.pid;
    bcr_out      = configPacketStruck.bcr;
    dcr_out      = configPacketStruck.dcr;
    dyn_addr_out = assigned_addr;

    dataPacketStruck.targetAddress       = 7'h7E;
    dataPacketStruck.targetAddressStatus = ACK;

    forever begin

      detect_rep_start_or_stop(got_rep_start);

      if (!got_rep_start) begin

        `uvm_info(
          name,
          "DAA: STOP detected - all devices assigned, exiting",
          UVM_NONE
        )

        return;

      end

      `uvm_info(
        name,
        "DAA: REP_START after assignment - consuming 7E+R, driving NACK",
        UVM_NONE
      )

      sample_daa_broadcast_read(dataPacketStruck);

    end

  endtask : drive_daa_data


  task automatic drive_daa_arb_bits(
    input  bit [63:0] my_id,
    output bit        won_arb,
    output int        lost_bit_out
  );

    bit my_bit;
    bit bus_bit;
    bit [63:0] all_bits = 0;
    bit first_bit = 0;
    bit [63:0] bus_val = 0;

    won_arb      = 1;
    lost_bit_out = 0;

    first_bit = sda_i;

    `uvm_info(
      "DRIVE_DAA_BITS",
      $sformatf("first bus bit =%b", first_bit),
      UVM_LOW
    )

    for (int i = 63; i >= 0; i--) begin

      my_bit = my_id[i];

      all_bits[i] = my_id[i];

      detectEdge_scl(NEGEDGE);

      drive_sda(my_bit);

      detectEdge_scl(POSEDGE);

      bus_bit = sda_i;

      bus_val[i] = sda_i;

      `uvm_info(
        "DRIVE_DAA_BITS",
        $sformatf(
          "curretn bus bit=%b",
          bus_val[i]
        ),
        UVM_LOW
      )

      if (i > 0) begin

        if (my_bit == 1'b1 && bus_bit == 1'b0) begin

          `uvm_info(
            name,
            $sformatf(
              "DAA ARB: Lost at bit %0d (drove 1, bus=0)",
              i
            ),
            UVM_NONE
          )

          drive_sda(1);

          won_arb      = 0;
          lost_bit_out = i;

          return;

        end

      end

    end

    `uvm_info(
      "DRIVE_DAA_BITS",
      $sformatf(
        "all 64 bits =%h",
        all_bits
      ),
      UVM_LOW
    )

    `uvm_info(
      "DRIVE_DAA_BITS",
      $sformatf(
        "all total bus bit=%h",
        bus_val
      ),
      UVM_LOW
    )

    `uvm_info(
      name,
      "DAA ARB: WON all 64 bits",
      UVM_NONE
    )

  endtask : drive_daa_arb_bits


  task automatic skip_remaining_winner_frame(
    input int lost_at_bit
  );

    `uvm_info(
      name,
      $sformatf(
        "skip_remaining_winner_frame: lost_at_bit=%0d, stepping through winner's remaining frame",
        lost_at_bit
      ),
      UVM_HIGH
    )

    for (int i = 0; i < lost_at_bit; i++) begin

      detectEdge_scl(NEGEDGE);
      detectEdge_scl(POSEDGE);

    end

    for (int k = 0; k < 8; k++) begin

      detectEdge_scl(NEGEDGE);
      detectEdge_scl(POSEDGE);

    end

    detectEdge_scl(NEGEDGE);
    detectEdge_scl(POSEDGE);
    detectEdge_scl(NEGEDGE);

    `uvm_info(
      name,
      "skip_remaining_winner_frame: stepped past winner's full ACK release",
      UVM_HIGH
    )

  endtask : skip_remaining_winner_frame


  task sample_daa_broadcast_address(
    inout i3c_transfer_bits_s pkt
  );

    bit [6:0] addr_bits;
    bit       rw_bit;
    bit [7:0] full_byte;

    `uvm_info(
      name,
      "DAA: sampling broadcast 0x7E+W",
      UVM_HIGH
    )

    for (int k = 6; k >= 0; k--) begin

      detectEdge_scl(POSEDGE);

      addr_bits[k] = sda_i;

      drive_sda(1);

    end

    detectEdge_scl(POSEDGE);

    rw_bit = sda_i;

    drive_sda(1);

    full_byte = {addr_bits, rw_bit};

    `uvm_info(
      name,
      $sformatf(
        "DAA: broadcast addr = 0x%0x (expect 0xFC)",
        full_byte
      ),
      UVM_NONE
    )

    detectEdge_scl(NEGEDGE);

    drive_sda(1'b0);

    detectEdge_scl(POSEDGE);

    detectEdge_scl(NEGEDGE);

    drive_sda(1'b1);

  endtask : sample_daa_broadcast_address


  task sample_daa_ccc_byte(
    inout i3c_transfer_bits_s pkt
  );

    bit [7:0] ccc_byte;

    `uvm_info(
      name,
      "DAA: sampling ENTDAA CCC byte",
      UVM_HIGH
    )

    for (int k = 7; k >= 0; k--) begin

      detectEdge_scl(POSEDGE);

      ccc_byte[k] = sda_i;

      drive_sda(1);

    end

    `uvm_info(
      name,
      $sformatf(
        "DAA: CCC byte = 0x%0x (expect 0x07)",
        ccc_byte
      ),
      UVM_NONE
    )

    detectEdge_scl(NEGEDGE);

    drive_sda(1'b0);

    detectEdge_scl(POSEDGE);

    detectEdge_scl(NEGEDGE);

    drive_sda(1'b1);

  endtask : sample_daa_ccc_byte


  task detect_repeated_start();

    bit [1:0] scl_loc;
    bit [1:0] sda_loc;

    do begin

      @(negedge pclk);

      scl_loc = {scl_loc[0], scl_i};
      sda_loc = {sda_loc[0], sda_i};

    end while (!(sda_loc == NEGEDGE && scl_loc == 2'b11));

    `uvm_info(
      name,
      "DAA: Repeated START detected",
      UVM_HIGH
    )

    scl_local = {scl_i, scl_i};

  endtask : detect_repeated_start


  task automatic detect_rep_start_or_stop(
    output bit got_rep_start
  );

    bit [1:0] scl_loc;
    bit [1:0] sda_loc;

    scl_loc = {scl_i, scl_i};
    sda_loc = {sda_i, sda_i};

    forever begin

      @(negedge pclk);

      scl_loc = {scl_loc[0], scl_i};
      sda_loc = {sda_loc[0], sda_i};

      if (scl_loc == 2'b11 && sda_loc == 2'b10) begin

        `uvm_info(
          name,
          $sformatf(
            "[target_id=%0d] start detected[REPEATED START]@ time=%0t",
            i3c_target_drv_proxy_h.i3c_target_agent_cfg_h.target_id,
            $time
          ),
          UVM_NONE
        )

        got_rep_start = 1;

        return;

      end

      if (scl_loc == 2'b11 && sda_loc == 2'b01) begin

        `uvm_info(
          name,
          $sformatf(
            "[target_id=%0d] detect_rep_start_or_stop(STOP): STOP @ time=%0t",
            i3c_target_drv_proxy_h.i3c_target_agent_cfg_h.target_id,
            $time
          ),
          UVM_NONE
        )

        got_rep_start = 0;

        return;

      end

    end

  endtask : detect_rep_start_or_stop


  task sample_daa_broadcast_read(
    inout i3c_transfer_bits_s pkt
  );

    bit [6:0] addr_bits;
    bit       rw_bit;
    bit [7:0] full_byte;

    `uvm_info(
      name,
      "DAA: sampling broadcast 0x7E+R",
      UVM_HIGH
    )

    detectEdge_scl(NEGEDGE);

    for (int k = 6; k >= 0; k--) begin

      detectEdge_scl(POSEDGE);

      addr_bits[k] = sda_i;

      drive_sda(1);

    end

    detectEdge_scl(POSEDGE);

    rw_bit = sda_i;

    drive_sda(1);

    full_byte = {addr_bits, rw_bit};

    `uvm_info(
      name,
      $sformatf(
        "DAA: broadcast read addr = 0x%0x (expect 0xFD)",
        full_byte
      ),
      UVM_NONE
    )

    detectEdge_scl(NEGEDGE);

    `uvm_info(
      "DAA_ACK_DEBUG",
      $sformatf(
        "[target_id=%0d] has_address=%0b -> driving %s on 7E+R ACK slot",
        i3c_target_drv_proxy_h.i3c_target_agent_cfg_h.target_id,
        has_address,
        has_address ? "NACK" : "ACK"
      ),
      UVM_NONE
    )

    drive_sda(
      has_address ? 1'b1 : 1'b0
    );

    detectEdge_scl(POSEDGE);

  endtask : sample_daa_broadcast_read


  task sample_daa_dynamic_address(
    output bit [6:0] dyn_addr_out,
    output bit [7:0] full_byte_out,
    output bit       ack_out
  );

    bit [7:0] addr_byte;
    bit       parity_received;
    bit       parity_calc;

    i3c_target_driver_proxy::daa_count++;

    `uvm_info(
      name,
      "DAA: sampling dynamic address",
      UVM_HIGH
    )

    for (int k = 7; k >= 0; k--) begin

      detectEdge_scl(POSEDGE);

      addr_byte[k] = sda_i;

      drive_sda(1);

    end

    dyn_addr_out    = addr_byte[7:1];
    parity_received = addr_byte[0];
    full_byte_out   = addr_byte;

    parity_calc = ~^addr_byte[7:1];

    `uvm_info(
      "COUNT_SLAVE",
      $sformatf(
        "Slave addr assignment done count=%d",
        i3c_target_driver_proxy::daa_count
      ),
      UVM_NONE
    )

    if (parity_calc == parity_received) begin

      ack_out = ACK;

      `uvm_info(
        name,
        $sformatf(
          "DAA: dynamic addr=%0h dyn_add+parity=%0h parity OK =%0b? ACK",
          dyn_addr_out,
          addr_byte,
          parity_received
        ),
        UVM_NONE
      )

    end
    else begin

      ack_out = NACK;

      `uvm_info(
        name,
        $sformatf(
          "DAA: dynamic addr=0x%0x parity FAIL ? NACK",
          dyn_addr_out
        ),
        UVM_NONE
      )

    end

  endtask : sample_daa_dynamic_address


  task detect_start();

    bit [1:0] scl_local_d;
    bit [1:0] sda_local_d;

    state = I3C_START;

    `uvm_info(
      name,
      "detect_start waiting",
      UVM_HIGH
    )

    do begin

      @(negedge pclk);

      scl_local_d = {scl_local_d[0], scl_i};
      sda_local_d = {sda_local_d[0], sda_i};

    end while (
      !(sda_local_d == NEGEDGE && scl_local_d == 2'b11)
    );

    `uvm_info(
      name,
      $sformatf(
        "[target_id=%0d] start detected@ time=%0t",
        i3c_target_drv_proxy_h.i3c_target_agent_cfg_h.target_id,
        $time
      ),
      UVM_NONE
    )

    scl_local = {scl_i, scl_i};

  endtask : detect_start


  task sample_target_address(
    input i3c_transfer_cfg_s cfg_pkt,
    inout i3c_transfer_bits_s pkt
  );

    bit [TARGET_ADDRESS_WIDTH-1:0] local_addr;

    `uvm_info(
      name,
      "sample_target_address started",
      UVM_HIGH
    )

    state = I3C_ADDRESS;

    for (
      int k = TARGET_ADDRESS_WIDTH-1;
      k >= 0;
      k--
    ) begin

      detectEdge_scl(POSEDGE);

      local_addr[k] = sda_i;

      `uvm_info(
        name,
        $sformatf(
          "sampled bit %0d = %0d",
          k,
          sda_i
        ),
        UVM_HIGH
      )

      drive_sda(1);

    end

    `uvm_info(
      name,
      $sformatf(
        "DEBUG :: local_addr = 0x%0x",
        local_addr[6:0]
      ),
      UVM_NONE
    )

    pkt.targetAddress = local_addr;

    `uvm_info(
      name,
      $sformatf(
        "DEBUG :: cfg target_addr = 0x%0x",
        cfg_pkt.targetAddress
      ),
      UVM_NONE
    )

    if (local_addr != cfg_pkt.targetAddress) begin

      pkt.targetAddressStatus = NACK;

      `uvm_info(
        name,
        "address mismatch NACK",
        UVM_HIGH
      )

    end
    else begin

      pkt.targetAddressStatus = ACK;

      `uvm_info(
        name,
        "address match ACK",
        UVM_HIGH
      )

    end

  endtask : sample_target_address


  task sample_operation(
    output operationType_e wr_rd
  );

    bit operation;

    state = I3C_WR_BIT;

    detectEdge_scl(POSEDGE);

    operation = sda_i;

    drive_sda(1);

    if (operation == 1'b0) begin

      wr_rd = I3C_WRITE;

      `uvm_info(
        name,
        "operation = WRITE",
        UVM_HIGH
      )

    end
    else begin

      wr_rd = I3C_READ;

      `uvm_info(
        name,
        "operation = READ",
        UVM_HIGH
      )

    end

  endtask : sample_operation


  task sample_address_parity(
    inout i3c_transfer_bits_s pkt
  );

    bit parity_rx;
    bit parity_exp;
    bit [7:0] addr_w_byte;

    detectEdge_scl(POSEDGE);

    addr_w_byte = {
      pkt.targetAddress,
      (pkt.operation == I3C_READ) ? 1'b1 : 1'b0
    };

    parity_exp = ^addr_w_byte;

    `uvm_info(
      name,
      $sformatf(
        "ADDR PARITY: addr+W=0x%02h parity_rx=%0b ^(addr+W)=%0b ? %s",
        addr_w_byte,
        parity_rx,
        parity_exp,
        (parity_rx == parity_exp) ? "OK" : "FAIL"
      ),
      UVM_NONE
    )

    if (parity_rx != parity_exp) begin

      pkt.targetAddressStatus = NACK;

      `uvm_error(
        name,
        "Address parity FAIL overriding to NACK"
      )

    end

  endtask : sample_address_parity


  task driveAddressAck(
    input bit ack
  );

    `uvm_info(
      name,
      $sformatf(
        "driveAddressAck = %0d",
        ack
      ),
      UVM_HIGH
    )

    state = I3C_ACK_NACK;

    detectEdge_scl(NEGEDGE);

    drive_sda(ack);

    `uvm_info(
      name,
      $sformatf(
        "[%0t] TARGET driving ACK=%0b sda_o=%0b sda_oen=%0b sda_i=%0b",
        $time,
        ack,
        sda_o,
        sda_oen,
        sda_i
      ),
      UVM_NONE
    )

    detectEdge_scl(POSEDGE);

    detectEdge_scl(NEGEDGE);

    drive_sda(1'b1);

    `uvm_info(
      name,
      $sformatf(
        "[%0t] TARGET released SDA sda_o=%0b sda_oen=%0b sda_i=%0b",
        $time,
        sda_o,
        sda_oen,
        sda_i
      ),
      UVM_NONE
    )

  endtask : driveAddressAck


  task sample_write_data(
    input i3c_transfer_cfg_s cfg_pkt,
    inout i3c_transfer_bits_s pkt,
    input int i
  );

    bit [I3C_DATA_WIDTH-1:0] wdata;

    state = I3C_WRITE_DATA;

    for (
      int k = 0, bit_no = 0;
      k < I3C_DATA_WIDTH;
      k++
    ) begin

      bit_no =
        (cfg_pkt.dataTransferDirection == MSB_FIRST) ?
        ((I3C_DATA_WIDTH - 1) - k) :
        k;

      detectEdge_scl(POSEDGE);

      wdata[bit_no] = sda_i;

      `uvm_info(
        name,
        $sformatf(
          "[%0t] SAMPLE bit[%0d] = %0b",
          $time,
          bit_no,
          sda_i
        ),
        UVM_NONE
      )

      pkt.no_of_i3c_bits_transfer++;

    end

    targetFIFOMemory.push_back(wdata);

    pkt.writeData[i]       = wdata;
    pkt.writeDataStatus[i] = ACK;

  endtask : sample_write_data


  task driveWdataAck(
    input bit ack
  );

    state = I3C_ACK_NACK;

    detectEdge_scl(NEGEDGE);

    drive_sda(ack);

    detectEdge_scl(POSEDGE);

    drive_sda(1'b1);

  endtask : driveWdataAck


  task drive_read_data(
    input bit [I3C_DATA_WIDTH-1:0] rdata_in,
    inout i3c_transfer_bits_s pkt,
    input int i,
    input dataTransferDirection_e dir
  );

    state = I3C_READ_DATA;

    for (
      int k = 0, bit_no = 0;
      k < I3C_DATA_WIDTH;
      k++
    ) begin

      bit_no =
        (dir == MSB_FIRST) ?
        ((I3C_DATA_WIDTH - 1) - k) :
        k;

      drive_sda(rdata_in[bit_no]);

      detectEdge_scl(NEGEDGE);

      pkt.no_of_i3c_bits_transfer++;

    end

    pkt.readData[i] = rdata_in;

  endtask : drive_read_data


  task sample_ack(
    output bit ack
  );

    state = I3C_ACK_NACK;

    detectEdge_scl(POSEDGE);

    ack = sda_i;

    detectEdge_scl(NEGEDGE);

  endtask : sample_ack


  task wrDetect_stop();

    bit [1:0] scl_d;
    bit [1:0] sda_d;

    forever begin

      do begin

        @(negedge pclk);

        #1;

        scl_d = {scl_d[0], scl_i};
        sda_d = {sda_d[0], sda_i};

      end while (
        !(sda_d == 2'b01 && scl_d == 2'b11)
      );

      @(negedge pclk);

      #1;

      scl_d = {scl_d[0], scl_i};
      sda_d = {sda_d[0], sda_i};

      if (scl_d == 2'b10) begin

        `uvm_info(
          name,
          "wrDetect_stop: ignoring false STOP candidate (SCL fell = inter-byte transition)",
          UVM_HIGH
        )

        continue;

      end

      state = I3C_STOP;

      `uvm_info(
        name,
        "wrDetect_stop: STOP condition confirmed",
        UVM_HIGH
      )

      return;

    end

  endtask : wrDetect_stop


  task detect_stop();

    bit [1:0] scl_d;
    bit [1:0] sda_d;

    state = I3C_STOP;

    do begin

      @(negedge pclk);

      #1;

      scl_d = {scl_d[0], scl_i};
      sda_d = {sda_d[0], sda_i};

    end while (
      !(sda_d == POSEDGE && scl_d == 2'b11)
    );

    `uvm_info(
      name,
      $sformatf(
        "[target_id=%0d] stop detected@ time=%0t",
        i3c_target_drv_proxy_h.i3c_target_agent_cfg_h.target_id,
        $time
      ),
      UVM_NONE
    )

  endtask : detect_stop


  task drive_sda(
    input bit value
  );

    sda_oen <= value ?
               TRISTATE_BUF_OFF :
               TRISTATE_BUF_ON;

    sda_o <= value;

  endtask : drive_sda


  task drive_scl(
    input bit value
  );

    scl_oen <= value ?
               TRISTATE_BUF_OFF :
               TRISTATE_BUF_ON;

    scl_o <= value;

  endtask : drive_scl


  task detectEdge_scl(
    input edge_detect_e edgeSCL
  );

    edge_detect_e scl_edge_value;

    do begin

      @(negedge pclk);

      scl_local = {scl_local[0], scl_i};

    end while (!(scl_local == edgeSCL));

    scl_edge_value = edge_detect_e'(scl_local);

    `uvm_info(
      "TARGET_DRIVER_BFM",
      $sformatf(
        "scl %s detected",
        scl_edge_value.name()
      ),
      UVM_HIGH
    )

  endtask : detectEdge_scl


  // HOT JOIN, IBI, and the commented-out HDR-DDR block below
  // remain unchanged.


  task wait_for_stable_bus_idle();

    int idle_cycles;

    idle_cycles = 0;

    forever begin

      @(posedge pclk);

      if (scl_i == 1'b1 && sda_i == 1'b1)
        idle_cycles++;
      else
        idle_cycles = 0;

      if (idle_cycles > 4)
        return;

    end

  endtask : wait_for_stable_bus_idle


  task automatic drive_hot_join_ibi(
    input  bit [6:0] hotjoin_addr,
    output bit       ibi_ack
  );

    bit [7:0] full_byte;
    bit       bus_bit = 0;

    full_byte = {hotjoin_addr, 1'b0};

    `uvm_info(
      name,
      "HOT_JOIN: waiting for stable bus idle before asserting IBI request",
      UVM_NONE
    )

    wait_for_stable_bus_idle();

    `uvm_info(
      name,
      "HOT_JOIN: asserting IBI request (SDA 1->0 while SCL high)",
      UVM_NONE
    )

    drive_sda(1'b0);

    detectEdge_scl(NEGEDGE);

    `uvm_info(
      name,
      $sformatf(
        "HOT_JOIN: driving IBI address byte = 0x%0h (addr=0x%0h, RnW=1)",
        full_byte,
        hotjoin_addr
      ),
      UVM_NONE
    )

    for (int k = 7; k >= 0; k--) begin

      drive_sda(full_byte[k]);

      detectEdge_scl(POSEDGE);

      bus_bit = sda_i;

      `uvm_info(
        "HOT_JOIN_BUS_BIT",
        $sformatf(
          "curretn bus bit=%b",
          bus_bit
        ),
        UVM_LOW
      )

      detectEdge_scl(NEGEDGE);

    end

    drive_sda(1'b1);

    sample_ack(ibi_ack);

    `uvm_info(
      "CHECK HOT JOIN",
      $sformatf(
        "HOT_JOIN: address ACK/NACK = %0b",
        ibi_ack
      ),
      UVM_NONE
    )

    `uvm_info(
      name,
      "HOT_JOIN: IBI address phase complete controller will restart ENTDAA for hot-join",
      UVM_NONE
    )

  endtask : drive_hot_join_ibi


  task drive_hot_join_data(
    input  bit [6:0] hotjoin_addr,
    inout  i3c_transfer_bits_s dataPacketStruck,
    input  i3c_transfer_cfg_s configPacketStruck,
    output bit [47:0] pid_out,
    output bit [7:0]  bcr_out,
    output bit [7:0]  dcr_out,
    output bit [6:0]  dyn_addr_out,
    output bit        daa_ack_out
  );

    bit ack;

    `uvm_info(
      name,
      "HOT_JOIN: transaction started",
      UVM_NONE
    )

    drive_hot_join_ibi(
      hotjoin_addr,
      ack
    );

    if (ack == 0) begin

      drive_daa_data(
        dataPacketStruck,
        configPacketStruck,
        pid_out,
        bcr_out,
        dcr_out,
        dyn_addr_out,
        daa_ack_out
      );

      `uvm_info(
        name,
        $sformatf(
          "HOT_JOIN: complete. daa_ack=%0b dynamic_addr=0x%0h",
          daa_ack_out,
          dyn_addr_out
        ),
        UVM_NONE
      )

    end
    else begin

      detect_stop();

    end

  endtask : drive_hot_join_data


  task automatic drive_ibi_request(
    input  bit [6:0] my_dyn_addr,
    output bit       ibi_ack_out
  );

    bit [7:0] full_byte;
    bit       bus_bit;

    full_byte = {my_dyn_addr, 1'b1};

    `uvm_info(
      name,
      "IBI: waiting for stable bus idle before asserting IBI request",
      UVM_NONE
    )

    wait_for_stable_bus_idle();

    `uvm_info(
      name,
      "IBI: asserting IBI request (SDA 1->0 while SCL high)",
      UVM_NONE
    )

    drive_sda(1'b0);

    detectEdge_scl(NEGEDGE);

    `uvm_info(
      name,
      $sformatf(
        "IBI: driving address byte = 0x%0h (addr=0x%0h, RnW=1)",
        full_byte,
        my_dyn_addr
      ),
      UVM_NONE
    )

    for (int k = 7; k >= 0; k--) begin

      drive_sda(full_byte[k]);

      detectEdge_scl(POSEDGE);

      bus_bit = sda_i;

      `uvm_info(
        "IBI_BUS_BIT",
        $sformatf(
          "current bus bit=%b",
          bus_bit
        ),
        UVM_LOW
      )

      detectEdge_scl(NEGEDGE);

    end

    `uvm_info(
      "IBI",
      $sformatf("done sending dynamic addr"),
      UVM_LOW
    )

    drive_sda(1'b1);

    sample_ack(ibi_ack_out);

    `uvm_info(
      "CHECK IBI",
      $sformatf(
        "IBI: address ACK/NACK = %0b",
        ibi_ack_out
      ),
      UVM_NONE
    )

  endtask : drive_ibi_request


  task automatic drive_ibi_payload_byte(
    input bit [7:0] data_in,
    input bit       t_bit_in
  );

    `uvm_info(
      name,
      $sformatf(
        "IBI: driving data byte = 0x%0h, T-bit=%0b (%0s)",
        data_in,
        t_bit_in,
        t_bit_in ?
          "MORE DATA" :
          "NO MORE DATA/STOP"
      ),
      UVM_NONE
    )

    for (int k = 7; k >= 0; k--) begin

      drive_sda(data_in[k]);

      detectEdge_scl(NEGEDGE);

    end

    drive_sda(t_bit_in);

    detectEdge_scl(NEGEDGE);

    if (!t_bit_in)
      drive_sda(1'b1);

    `uvm_info(
      "IBI_DEBUG_T",
      $sformatf(
        "IBI: data byte 0x%0h complete, T-bit driven=%0b",
        data_in,
        t_bit_in
      ),
      UVM_NONE
    )

  endtask : drive_ibi_payload_byte


  task drive_ibi_data(
    input  bit [6:0] my_dyn_addr,
    input  bit [7:0] mdb_in,
    input  int unsigned num_extra_bytes,
    input  bit [7:0] extra_data_in[],
    output bit       ibi_ack_out,
    output bit       t1_out,
    output bit [7:0] extra_data_sent_out[],
    output bit       extra_t_bits_out[]
  );

    t1_out              = 1'b0;
    extra_data_sent_out = new[0];
    extra_t_bits_out    = new[0];

    `uvm_info(
      name,
      "IBI: transaction started",
      UVM_NONE
    )

    drive_ibi_request(
      my_dyn_addr,
      ibi_ack_out
    );

    if (ibi_ack_out == ACK) begin

      t1_out = (num_extra_bytes > 0);

      drive_ibi_payload_byte(
        mdb_in,
        t1_out
      );

      if (num_extra_bytes > 0) begin

        extra_data_sent_out = new[num_extra_bytes];
        extra_t_bits_out    = new[num_extra_bytes];

        for (int k = 0; k < num_extra_bytes; k++) begin

          bit t_this;

          t_this =
            (k < num_extra_bytes - 1) ?
            1'b1 :
            1'b0;

          `uvm_info(
            name,
            $sformatf(
              "IBI: target driving extra byte[%0d]=0x%0h, T=%0b (%0s)",
              k,
              extra_data_in[k],
              t_this,
              t_this ?
                "MORE DATA" :
                "NO MORE DATA/STOP"
            ),
            UVM_NONE
          )

          drive_ibi_payload_byte(
            extra_data_in[k],
            t_this
          );

          extra_data_sent_out[k] = extra_data_in[k];
          extra_t_bits_out[k]    = t_this;

        end

      end

      detect_stop();

      `uvm_info(
        name,
        "IBI: complete, controller issued STOP",
        UVM_NONE
      )

    end
    else begin

      `uvm_info(
        name,
        "IBI: request NACKed by controller, no payload sent",
        UVM_NONE
      )

    end

  endtask : drive_ibi_data


  // HDR-DDR block -- fully commented out, untouched, unchanged from before.
  /* ... (unchanged) ... */


endinterface : i3c_target_driver_bfm

`endif
