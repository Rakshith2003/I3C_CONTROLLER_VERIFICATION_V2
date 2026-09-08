`ifndef I3C_SCOREBOARD_INCLUDED_
`define I3C_SCOREBOARD_INCLUDED_

class i3c_scoreboard extends uvm_component;

  `uvm_component_utils(i3c_scoreboard)

  uvm_tlm_analysis_fifo #(apb_master_tx) apb_analysis_fifo;
  uvm_tlm_analysis_fifo #(i3c_target_tx) target_analysis_fifo[];
  uvm_tlm_analysis_fifo #(i3c_target_tx) ibi_analysis_fifo[];

  i3c_env_config i3c_env_cfg_h;

  int apb_tx_count;
  int target_tx_count;

  int write_pass;
  int write_fail;
  int read_pass;
  int read_fail;

  int daa_addr_pass;
  int daa_addr_fail;
  int daa_parity_pass;
  int daa_parity_fail;
  int daa_devices_seen;

  int ibi_pass;
  int ibi_fail;

  bit [6:0] exp_address;
  bit [7:0] exp_length;
  bit       exp_direction;
  bit [1:0] exp_cmd_type;
  bit [7:0] exp_ccc;

  // SDR data queues
  bit [7:0] exp_write_data[$];
  bit [7:0] exp_rd_wr_data[$];

  typedef struct {
    bit         assigned;
    bit [6:0]   dynamic_address;
    bit [47:0]  pid;
    bit [7:0]   bcr;
    bit [7:0]   dcr;
    bit         daa_ack;
  } daa_result_t;

  daa_result_t daa_result[];

  bit [6:0] daa_next_exp_addr;

  event daa_initial_round_done_ev;

  extern function new(
    string name = "i3c_scoreboard",
    uvm_component parent = null
  );

  extern virtual function void build_phase(uvm_phase phase);

  extern virtual task run_phase(uvm_phase phase);

  extern virtual function void check_phase(uvm_phase phase);

  // SDR
  extern protected task collect_apb_transaction();

  extern protected task compare_with_target();

  extern protected function void decode_ctrl(
    bit [31:0] ctrl_val
  );

  // DAA
  extern protected function bit is_daa_transaction();

  extern protected task compare_with_daa_target();

  // HOT JOIN
  extern protected task check_hot_join_results();

  // IBI
  extern protected task check_ibi_results();

  // helpers
  extern protected function int find_target_by_address(
    bit [6:0] addr
  );

endclass : i3c_scoreboard


//--------------------------------------------------------------------------------------------
// Constructor
//--------------------------------------------------------------------------------------------

function i3c_scoreboard::new(
  string name = "i3c_scoreboard",
  uvm_component parent = null
);

  super.new(name, parent);

endfunction : new


//--------------------------------------------------------------------------------------------
// Build Phase
//--------------------------------------------------------------------------------------------

function void i3c_scoreboard::build_phase(uvm_phase phase);

  super.build_phase(phase);

  if (!uvm_config_db #(i3c_env_config)::get(
        this,
        "",
        "i3c_env_config",
        i3c_env_cfg_h
      ))
    `uvm_fatal(
      "SB_CFG",
      "Cannot get i3c_env_config from config_db"
    )

  // APB fifo (single master)
  apb_analysis_fifo = new(
    "apb_analysis_fifo",
    this
  );

  // Per-slave target fifos
  target_analysis_fifo =
    new[i3c_env_cfg_h.no_of_targets];

  foreach (target_analysis_fifo[i]) begin

    target_analysis_fifo[i] = new(
      $sformatf(
        "target_analysis_fifo_%0d",
        i
      ),
      this
    );

  end

  // IBI -- port handle
  ibi_analysis_fifo =
    new[i3c_env_cfg_h.no_of_targets];

  foreach (ibi_analysis_fifo[i]) begin

    ibi_analysis_fifo[i] = new(
      $sformatf(
        "ibi_analysis_fifo_%0d",
        i
      ),
      this
    );

  end

  // Per-slave DAA result table
  daa_result =
    new[i3c_env_cfg_h.no_of_targets];

  foreach (daa_result[i]) begin

    daa_result[i].assigned =
      0;

    daa_result[i].dynamic_address =
      7'h00;

    daa_result[i].pid =
      48'h0;

    daa_result[i].bcr =
      8'h00;

    daa_result[i].dcr =
      8'h00;

    daa_result[i].daa_ack =
      NACK;

  end

  daa_next_exp_addr =
    DAA_FIRST_DYN_ADDR;

  `uvm_info(
    "SB",
    $sformatf(
      "Scoreboard built for %0d target(s)",
      i3c_env_cfg_h.no_of_targets
    ),
    UVM_LOW
  )

endfunction : build_phase


//--------------------------------------------------------------------------------------------
// Run Phase
//--------------------------------------------------------------------------------------------

task i3c_scoreboard::run_phase(uvm_phase phase);

  super.run_phase(phase);

  fork

    check_hot_join_results();

    check_ibi_results();

  join_none

  forever begin

    collect_apb_transaction();

    if (is_daa_transaction()) begin

      `uvm_info(
        "SB",
        $sformatf(
          "DAA transaction detected: cmd_type=0x%0x ccc=0x%0x",
          exp_cmd_type,
          exp_ccc
        ),
        UVM_MEDIUM
      )

      compare_with_daa_target();

      -> daa_initial_round_done_ev;

    end
    else begin

      compare_with_target();

    end

  end

endtask : run_phase


//--------------------------------------------------------------------------------------------
// Collect APB Transaction
//--------------------------------------------------------------------------------------------

task i3c_scoreboard::collect_apb_transaction();

  apb_master_tx apb_pkt;

  exp_write_data.delete();

  forever begin

    apb_analysis_fifo.get(apb_pkt);

    apb_tx_count++;

    // Accumulate WDATAB writes (addr 0x30)
    if (
      apb_pkt.pwrite == apb_global_pkg::APB_WRITE &&
      apb_pkt.paddr[6:0] == 7'h30
    ) begin

      exp_write_data.push_back(
        apb_pkt.pwdata[7:0]
      );

      exp_rd_wr_data.push_back(
        apb_pkt.pwdata[7:0]
      );

      `uvm_info(
        "SB",
        $sformatf(
          "WDATAB collected = 0x%0x",
          apb_pkt.pwdata[7:0]
        ),
        UVM_HIGH
      )

    end

    // CTRL write with start bit set
    // addr 0x0C, bit[31]=1
    if (
      apb_pkt.pwrite == apb_global_pkg::APB_WRITE &&
      apb_pkt.paddr[6:0] == 7'h0C &&
      apb_pkt.pwdata[31] == 1'b1
    ) begin

      decode_ctrl(apb_pkt.pwdata);

      `uvm_info(
        "SB",
        $sformatf(
          "CTRL decoded: addr=0x%0x dir=%0b len=%0d cmd_type=0x%0x ccc=0x%0x",
          exp_address,
          exp_direction,
          exp_length,
          exp_cmd_type,
          exp_ccc
        ),
        UVM_MEDIUM
      )

      break;

    end

  end

endtask : collect_apb_transaction


//--------------------------------------------------------------------------------------------
// Decode CTRL
//--------------------------------------------------------------------------------------------

function void i3c_scoreboard::decode_ctrl(
  bit [31:0] ctrl_val
);

  exp_address =
    ctrl_val[6:0];

  exp_length =
    ctrl_val[14:7];

  exp_direction =
    ctrl_val[15];

  exp_ccc =
    ctrl_val[23:16];

  exp_cmd_type =
    ctrl_val[25:24];

endfunction : decode_ctrl


//--------------------------------------------------------------------------------------------
// Check DAA Transaction
//--------------------------------------------------------------------------------------------

function bit i3c_scoreboard::is_daa_transaction();

  if (exp_cmd_type == CMD_TYPE_DAA)
    return 1;

  if (
    exp_cmd_type == CMD_TYPE_CCC &&
    exp_ccc == ENTDAA_CCC_CODE
  )
    return 1;

  return 0;

endfunction : is_daa_transaction


//--------------------------------------------------------------------------------------------
// Compare DAA Target
//--------------------------------------------------------------------------------------------

task i3c_scoreboard::compare_with_daa_target();

  i3c_target_tx tgt;

  bit [6:0] exp_dyn_addr;

  int num_targets;
  int targets_processed;

  num_targets =
    i3c_env_cfg_h.no_of_targets;

  targets_processed =
    0;

  if (exp_cmd_type == CMD_TYPE_CCC) begin

    if (exp_ccc == ENTDAA_CCC_CODE)

      `uvm_info(
        "SB_DAA_CTRL_CCC",
        "CTRL CCC = 0x07 (ENTDAA) PASS",
        UVM_MEDIUM
      )

    else

      `uvm_error(
        "SB_DAA_CTRL_CCC",
        $sformatf(
          "cmd_type=2 but CCC=0x%0h, expected ENTDAA=0x07",
          exp_ccc
        )
      )

  end
  else begin

    `uvm_info(
      "SB_DAA_CTRL_CMD",
      "CTRL cmd_type = 3 (explicit DAA) PASS",
      UVM_MEDIUM
    )

  end

  while (targets_processed < num_targets) begin

    for (int i = 0; i < num_targets; i++) begin

      // Skip slots already processed this round
      if (daa_result[i].assigned)
        continue;

      if (target_analysis_fifo[i].try_get(tgt)) begin

        target_tx_count++;
        daa_devices_seen++;
        targets_processed++;

        `uvm_info(
          "SB_DAA",
          $sformatf(
            "Got DAA result from target[%0d]: PID=0x%0h BCR=0x%0h DCR=0x%0h dynAddr=0x%0h daa_ack=%0b",
            i,
            tgt.pid,
            tgt.bcr,
            tgt.dcr,
            tgt.dynamic_address,
            tgt.daa_ack
          ),
          UVM_MEDIUM
        )

        // -- txn_type check
        if (tgt.txn_type !== i3c_target_tx::DAA) begin

          `uvm_error(
            "SB_DAA_TXN_TYPE",
            $sformatf(
              "[target %0d] Expected DAA txn but got txn_type=%s",
              i,
              tgt.txn_type.name()
            )
          )

        end

        // -- Store result
        daa_result[i].assigned =
          1;

        daa_result[i].dynamic_address =
          tgt.dynamic_address;

        daa_result[i].pid =
          tgt.pid;

        daa_result[i].bcr =
          tgt.bcr;

        daa_result[i].dcr =
          tgt.dcr;

        daa_result[i].daa_ack =
          tgt.daa_ack;

        // -- Parity / ACK check
        if (tgt.daa_ack === ACK) begin

          `uvm_info(
            "SB_DAA_ACK",
            $sformatf(
              "[target %0d] daa_ack=ACK for addr 0x%0h PASS",
              i,
              tgt.dynamic_address
            ),
            UVM_MEDIUM
          )

          daa_parity_pass++;

          // -- Sequential dynamic address check
          exp_dyn_addr =
            daa_next_exp_addr;

          // Always advance so later slaves get
          // the right expected address
          daa_next_exp_addr++;

          if (tgt.dynamic_address !== exp_dyn_addr) begin

            `uvm_error(
              "SB_DAA_DYNADDR",
              $sformatf(
                "[target %0d] Dynamic address: expected 0x%0h got 0x%0h",
                i,
                exp_dyn_addr,
                tgt.dynamic_address
              )
            )

            daa_addr_fail++;

          end
          else begin

            `uvm_info(
              "SB_DAA_DYNADDR",
              $sformatf(
                "[target %0d] Dynamic address 0x%0h PASS",
                i,
                tgt.dynamic_address
              ),
              UVM_MEDIUM
            )

            daa_addr_pass++;

          end

          // -- BCR[7] must be 0 (target device role)
          if (tgt.bcr[7] !== 1'b0)

            `uvm_error(
              "SB_DAA_BCR_ROLE",
              $sformatf(
                "[target %0d] BCR[7] must be 0 but got 1 (PID=0x%0h)",
                i,
                tgt.pid
              )
            )

          else

            `uvm_info(
              "SB_DAA_BCR_ROLE",
              $sformatf(
                "[target %0d] BCR[7]=0 (target role) PASS",
                i
              ),
              UVM_MEDIUM
            )

          // -- PID non-zero
          if (tgt.pid === 48'h0)

            `uvm_error(
              "SB_DAA_PID_ZERO",
              $sformatf(
                "[target %0d] PID is zero - invalid",
                i
              )
            )

          // -- Cross-check PID
          if (
            i3c_env_cfg_h.i3c_target_agent_cfg_h[i].pid !==
            tgt.pid
          )

            `uvm_error(
              "SB_DAA_PID_MISMATCH",
              $sformatf(
                "[target %0d] PID: configured=0x%0h received=0x%0h",
                i,
                i3c_env_cfg_h.i3c_target_agent_cfg_h[i].pid,
                tgt.pid
              )
            )

          else

            `uvm_info(
              "SB_DAA_PID",
              $sformatf(
                "[target %0d] PID 0x%0h matches config PASS",
                i,
                tgt.pid
              ),
              UVM_MEDIUM
            )

          // -- BCR cross-check
          if (
            i3c_env_cfg_h.i3c_target_agent_cfg_h[i].bcr !==
            tgt.bcr
          )

            `uvm_error(
              "SB_DAA_BCR_MISMATCH",
              $sformatf(
                "[target %0d] BCR: configured=0x%0h received=0x%0h",
                i,
                i3c_env_cfg_h.i3c_target_agent_cfg_h[i].bcr,
                tgt.bcr
              )
            )

          else

            `uvm_info(
              "SB_DAA_BCR",
              $sformatf(
                "[target %0d] BCR 0x%0h PASS",
                i,
                tgt.bcr
              ),
              UVM_MEDIUM
            )

          // -- DCR cross-check
          if (
            i3c_env_cfg_h.i3c_target_agent_cfg_h[i].dcr !==
            tgt.dcr
          )

            `uvm_error(
              "SB_DAA_DCR_MISMATCH",
              $sformatf(
                "[target %0d] DCR: configured=0x%0h received=0x%0h",
                i,
                i3c_env_cfg_h.i3c_target_agent_cfg_h[i].dcr,
                tgt.dcr
              )
            )

          else

            `uvm_info(
              "SB_DAA_DCR",
              $sformatf(
                "[target %0d] DCR 0x%0h PASS",
                i,
                tgt.dcr
              ),
              UVM_MEDIUM
            )

        end
        else begin

          `uvm_info(
            "SB_DAA_ACK",
            $sformatf(
              "[target %0d] daa_ack=NACK this round (not assigned yet)",
              i
            ),
            UVM_MEDIUM
          )

        end

      end

    end

    // Yield time slice so other processes
    // can push items into fifos
    if (targets_processed < num_targets)
      #1;

  end

  // Reset assigned flags for next ENTDAA command
  foreach (daa_result[i])
    daa_result[i].assigned = 0;

  `uvm_info(
    "SB_DAA",
    $sformatf(
      "DAA round complete: %0d/%0d devices assigned",
      targets_processed,
      num_targets
    ),
    UVM_LOW
  )

endtask : compare_with_daa_target


//--------------------------------------------------------------------------------------------
// Hot Join Results
//--------------------------------------------------------------------------------------------

task i3c_scoreboard::check_hot_join_results();

  i3c_target_tx tgt_i;

  bit [6:0] exp_dyn_addr;

  int num_targets;

  num_targets =
    i3c_env_cfg_h.no_of_targets;

  @(daa_initial_round_done_ev);

  `uvm_info(
    "SB_HOTJOIN",
    "Initial DAA round processed - now watching for hot-join round result(s)",
    UVM_MEDIUM
  )

  forever begin

    for (int i = 0; i < num_targets; i++) begin

      if (target_analysis_fifo[i].try_get(tgt_i)) begin

        target_tx_count++;

        if (tgt_i.hotjoin_addr != 7'h0) begin

          `uvm_info(
            "SB_HOTJOIN",
            $sformatf(
              "[target %0d] HOTJOIN result: ibi_addr=0x%0h daa_ack=%0b dynamic_addr=0x%0h PID=0x%0h BCR=0x%0h DCR=0x%0h",
              i,
              tgt_i.hotjoin_addr,
              tgt_i.daa_ack,
              tgt_i.dynamic_address,
              tgt_i.pid,
              tgt_i.bcr,
              tgt_i.dcr
            ),
            UVM_LOW
          )

          if (tgt_i.txn_type !== i3c_target_tx::DAA)

            `uvm_error(
              "SB_HOTJOIN_TXN_TYPE",
              $sformatf(
                "[target %0d] Expected DAA-shaped txn for hot-join result but got txn_type=%s",
                i,
                tgt_i.txn_type.name()
              )
            )

          if (tgt_i.daa_ack !== ACK) begin

            `uvm_error(
              "SB_HOTJOIN_ACK",
              $sformatf(
                "[target %0d] HOT JOIN FAILED: daa_ack=NACK (no dynamic address assigned)",
                i
              )
            )

            daa_parity_fail++;

          end
          else begin

            daa_parity_pass++;

            exp_dyn_addr =
              daa_next_exp_addr;

            daa_next_exp_addr++;

            if (tgt_i.dynamic_address !== exp_dyn_addr) begin

              `uvm_error(
                "SB_HOTJOIN_DYNADDR",
                $sformatf(
                  "[target %0d] HOTJOIN dynamic address: expected 0x%0h got 0x%0h",
                  i,
                  exp_dyn_addr,
                  tgt_i.dynamic_address
                )
              )

              daa_addr_fail++;

            end
            else begin

              `uvm_info(
                "SB_HOTJOIN_DYNADDR",
                $sformatf(
                  "[target %0d] HOTJOIN dynamic address 0x%0h PASS",
                  i,
                  tgt_i.dynamic_address
                ),
                UVM_MEDIUM
              )

              daa_addr_pass++;

            end

            // -- BCR[7] must be 0
            if (tgt_i.bcr[7] !== 1'b0)

              `uvm_error(
                "SB_HOTJOIN_BCR_ROLE",
                $sformatf(
                  "[target %0d] BCR[7] must be 0 but got 1 (PID=0x%0h)",
                  i,
                  tgt_i.pid
                )
              )

            // -- PID non-zero
            if (tgt_i.pid === 48'h0)

              `uvm_error(
                "SB_HOTJOIN_PID_ZERO",
                $sformatf(
                  "[target %0d] PID is zero - invalid",
                  i
                )
              )

            // -- Cross-check against configured identity
            if (
              i3c_env_cfg_h.i3c_target_agent_cfg_h[i].pid !==
              tgt_i.pid
            )

              `uvm_error(
                "SB_HOTJOIN_PID_MISMATCH",
                $sformatf(
                  "[target %0d] PID: configured=0x%0h received=0x%0h",
                  i,
                  i3c_env_cfg_h.i3c_target_agent_cfg_h[i].pid,
                  tgt_i.pid
                )
              )

            // -- Store result
            daa_result[i].assigned =
              1;

            daa_result[i].dynamic_address =
              tgt_i.dynamic_address;

            daa_result[i].pid =
              tgt_i.pid;

            daa_result[i].bcr =
              tgt_i.bcr;

            daa_result[i].dcr =
              tgt_i.dcr;

            daa_result[i].daa_ack =
              tgt_i.daa_ack;

            daa_devices_seen++;

          end

        end
        else begin

          `uvm_info(
            "SB_HOTJOIN",
            $sformatf(
              "[target %0d] Draining stale post-round monitor report (daa_ack=%0b) - not the hot-joining target",
              i,
              tgt_i.daa_ack
            ),
            UVM_HIGH
          )

        end

      end

    end

    #1ns;

  end

endtask : check_hot_join_results


//--------------------------------------------------------------------------------------------
// IBI Results
//--------------------------------------------------------------------------------------------

task i3c_scoreboard::check_ibi_results();

  i3c_target_tx tgt_i;

  int num_targets;

  bit [7:0] exp_mdb;
  bit [6:0] exp_addr;

  num_targets =
    i3c_env_cfg_h.no_of_targets;

  `uvm_info(
    "SB_IBI",
    "Watching for IBI (In-Band Interrupt) result(s)",
    UVM_MEDIUM
  )

  forever begin

    for (int i = 0; i < num_targets; i++) begin

      if (ibi_analysis_fifo[i].try_get(tgt_i)) begin

        if (tgt_i.txn_type !== i3c_target_tx::IBI) begin

          `uvm_error(
            "SB_IBI_TXN_TYPE",
            $sformatf(
              "[target %0d] Expected IBI-tagged txn on ibi_analysis_fifo but got txn_type=%s",
              i,
              tgt_i.txn_type.name()
            )
          )

          continue;

        end

        target_tx_count++;

        `uvm_info(
          "SB_IBI",
          $sformatf(
            "[target %0d] IBI result: addr=0x%0h ack=%0b mdb=0x%0h T1=%0b extra_bytes_sent=%0d",
            i,
            tgt_i.dynamic_address,
            tgt_i.daa_ack,
            tgt_i.ibi_mdb,
            tgt_i.ibi_t1,
            tgt_i.ibi_extra_data_sent.size()
          ),
          UVM_LOW
        )

        if (tgt_i.daa_ack !== ACK) begin

          `uvm_error(
            "SB_IBI_ACK",
            $sformatf(
              "[target %0d] IBI FAILED: request NACKed by controller",
              i
            )
          )

          ibi_fail++;

          continue;

        end

        exp_addr =
          i3c_env_cfg_h.i3c_target_agent_cfg_h[i].targetAddress;

        if (tgt_i.dynamic_address !== exp_addr) begin

          `uvm_error(
            "SB_IBI_ADDR",
            $sformatf(
              "[target %0d] IBI address mismatch: expected 0x%0h (its assigned dynamic address) got 0x%0h",
              i,
              exp_addr,
              tgt_i.dynamic_address
            )
          )

          ibi_fail++;

          continue;

        end

        // -- MDB payload
        exp_mdb =
          i3c_env_cfg_h.i3c_target_agent_cfg_h[i].ibi_mdb;

        if (tgt_i.ibi_mdb !== exp_mdb) begin

          `uvm_error(
            "SB_IBI_MDB",
            $sformatf(
              "[target %0d] IBI MDB mismatch: expected 0x%0h got 0x%0h",
              i,
              exp_mdb,
              tgt_i.ibi_mdb
            )
          )

          ibi_fail++;

        end
        else begin

          `uvm_info(
            "SB_IBI_MDB",
            $sformatf(
              "[target %0d] IBI MDB 0x%0h PASS",
              i,
              tgt_i.ibi_mdb
            ),
            UVM_MEDIUM
          )

          ibi_pass++;

        end

        // -- T-bit / N extra data bytes
        `uvm_info(
          "SB_IBI_TBIT",
          $sformatf(
            "[target %0d] IBI T-bit driven by target after MDB: T1=%0b (%0s)",
            i,
            tgt_i.ibi_t1,
            tgt_i.ibi_t1 ?
              "more data follows" :
              "end of data (STOP)"
          ),
          UVM_MEDIUM
        )

        if (tgt_i.ibi_extra_data_sent.size() > 0) begin

          bit [7:0] exp_extra_data[];

          exp_extra_data =
            i3c_env_cfg_h.i3c_target_agent_cfg_h[i].ibi_extra_data;

          foreach (tgt_i.ibi_extra_data_sent[k]) begin

            bit [7:0] exp_val;
            bit       exp_t;

            exp_val =
              (k < exp_extra_data.size()) ?
              exp_extra_data[k] :
              8'hFF;

            if (
              tgt_i.ibi_extra_data_sent[k] !==
              exp_val
            ) begin

              `uvm_error(
                "SB_IBI_EXTRA_DATA",
                $sformatf(
                  "[target %0d] IBI extra byte[%0d] mismatch: expected 0x%0h got 0x%0h",
                  i,
                  k,
                  exp_val,
                  tgt_i.ibi_extra_data_sent[k]
                )
              )

              ibi_fail++;

            end
            else begin

              `uvm_info(
                "SB_IBI_EXTRA_DATA",
                $sformatf(
                  "[target %0d] IBI extra byte[%0d] 0x%0h PASS",
                  i,
                  k,
                  tgt_i.ibi_extra_data_sent[k]
                ),
                UVM_MEDIUM
              )

              ibi_pass++;

            end

            // Every extra byte except the last must carry T=1.
            // Last byte must carry T=0.
            exp_t =
              (k < tgt_i.ibi_extra_data_sent.size() - 1) ?
              1'b1 :
              1'b0;

            if (
              tgt_i.ibi_extra_t_bits[k] !==
              exp_t
            ) begin

              `uvm_error(
                "SB_IBI_EXTRA_TBIT",
                $sformatf(
                  "[target %0d] IBI extra byte[%0d] T-bit mismatch: expected %0b got %0b",
                  i,
                  k,
                  exp_t,
                  tgt_i.ibi_extra_t_bits[k]
                )
              )

              ibi_fail++;

            end

          end

        end
        else if (
          i3c_env_cfg_h.i3c_target_agent_cfg_h[i].ibi_num_extra_bytes > 0
        ) begin

          `uvm_info(
            "SB_IBI_EXTRA_DATA",
            $sformatf(
              "[target %0d] Target was configured to send %0d extra IBI data byte(s) but none were sent (transaction likely did not complete)",
              i,
              i3c_env_cfg_h.i3c_target_agent_cfg_h[i].ibi_num_extra_bytes
            ),
            UVM_MEDIUM
          )

        end

      end

    end

    #1ns;

  end

endtask : check_ibi_results


//--------------------------------------------------------------------------------------------
// Find Target By Address
//--------------------------------------------------------------------------------------------

function int i3c_scoreboard::find_target_by_address(
  bit [6:0] addr
);

  foreach (
    i3c_env_cfg_h.i3c_target_agent_cfg_h[i]
  ) begin

    if (
      i3c_env_cfg_h.i3c_target_agent_cfg_h[i].targetAddress ==
      addr
    )
      return i;

  end

  return -1;

endfunction : find_target_by_address


//--------------------------------------------------------------------------------------------
// Compare With Target
//--------------------------------------------------------------------------------------------

task i3c_scoreboard::compare_with_target();

  i3c_target_tx tgt;

  int tgt_idx;

  // Find which slave this SDR transaction
  // was directed to
  tgt_idx =
    find_target_by_address(exp_address);

  if (tgt_idx < 0) begin

    `uvm_error(
      "SB_SDR_NO_TARGET",
      $sformatf(
        "SDR: Cannot find target for address 0x%0x",
        exp_address
      )
    )

    return;

  end

  `uvm_info(
    "SB_SDR",
    $sformatf(
      "SDR: collecting from target_analysis_fifo[%0d] addr=0x%0x",
      tgt_idx,
      exp_address
    ),
    UVM_MEDIUM
  )

  target_analysis_fifo[tgt_idx].get(tgt);

  target_tx_count++;

  `uvm_info(
    "SB",
    $sformatf(
      "Target[%0d] pkt:\n%s",
      tgt_idx,
      tgt.sprint()
    ),
    UVM_HIGH
  )

  //------------------------------------------------------------------------------------------
  // Operation check
  //------------------------------------------------------------------------------------------

  begin

    operationType_e exp_op =
      (exp_direction == 1'b0) ?
      i3c_globals_pkg::I3C_WRITE :
      i3c_globals_pkg::I3C_READ;

    if (exp_op == tgt.operation)

      `uvm_info(
        "SB_OP_MATCH",
        $sformatf(
          "[target %0d] Operation %s PASS",
          tgt_idx,
          exp_op.name()
        ),
        UVM_MEDIUM
      )

    else

      `uvm_error(
        "SB_OP_MISMATCH",
        $sformatf(
          "[target %0d] Operation: expected %s got %s",
          tgt_idx,
          exp_op.name(),
          tgt.operation.name()
        )
      )

  end

  //------------------------------------------------------------------------------------------
  // WRITE data comparison
  //------------------------------------------------------------------------------------------

  if (exp_direction == 1'b0) begin

    int actual_bytes =
      tgt.writeData.size();

    `uvm_info(
      "SB",
      $sformatf(
        "[target %0d] Write: APB sent %0d bytes, CTRL length=%0d, target received %0d bytes",
        tgt_idx,
        exp_write_data.size(),
        exp_length,
        actual_bytes
      ),
      UVM_MEDIUM
    )

    for (
      int i = 0;
      i < actual_bytes;
      i++
    ) begin

      bit [7:0] exp_val;

      exp_val =
        (i < exp_write_data.size()) ?
        exp_write_data[i] :
        8'hFF;

      if (
        exp_val ==
        tgt.writeData[i][7:0]
      ) begin

        `uvm_info(
          "SB_WDATA_MATCH",
          $sformatf(
            "[target %0d] writeData[%0d]: expected 0x%0x got 0x%0x PASS",
            tgt_idx,
            i,
            exp_val,
            tgt.writeData[i][7:0]
          ),
          UVM_MEDIUM
        )

        write_pass++;

      end
      else begin

        `uvm_error(
          "SB_WDATA_MISMATCH",
          $sformatf(
            "[target %0d] writeData[%0d]: expected 0x%0x got 0x%0x FAIL",
            tgt_idx,
            i,
            exp_val,
            tgt.writeData[i][7:0]
          )
        )

        write_fail++;

      end

    end

    if (
      exp_write_data.size() >
      actual_bytes
    )

      `uvm_info(
        "SB_FIFO_OVERFLOW",
        $sformatf(
          "[target %0d] APB sent %0d bytes, target got %0d, RTL may have dropped %0d",
          tgt_idx,
          exp_write_data.size(),
          actual_bytes,
          exp_write_data.size() - actual_bytes
        ),
        UVM_MEDIUM
      )

  end

  //------------------------------------------------------------------------------------------
  // READ data comparison
  //------------------------------------------------------------------------------------------

  else begin

    bit [7:0] apb_read_data[$];

    apb_master_tx rd_pkt;

    int rd_count = 0;

    while (
      rd_count <
      int'(exp_length)
    ) begin

      apb_analysis_fifo.get(rd_pkt);

      apb_tx_count++;

      if (
        rd_pkt.pwrite ==
        apb_global_pkg::APB_READ &&
        rd_pkt.paddr[6:0] ==
        7'h40
      ) begin

        apb_read_data.push_back(
          rd_pkt.prdata[7:0]
        );

        `uvm_info(
          "SB",
          $sformatf(
            "[target %0d] RDATAB[%0d] = 0x%0x",
            tgt_idx,
            rd_count,
            rd_pkt.prdata[7:0]
          ),
          UVM_HIGH
        )

        rd_count++;

      end

    end

    if (
      apb_read_data.size() !=
      tgt.readData.size()
    ) begin

      `uvm_error(
        "SB_RDATA_SIZE",
        $sformatf(
          "[target %0d] Read size mismatch: apb=%0d target=%0d",
          tgt_idx,
          apb_read_data.size(),
          tgt.readData.size()
        )
      )

    end
    else begin

      for (
        int i = 0;
        i < tgt.readData.size();
        i++
      ) begin

        bit [7:0] exp_val;

        if (
          i <
          exp_rd_wr_data.size()
        )

          exp_val =
            exp_rd_wr_data[i];

        else begin

          exp_val =
            8'hFF;

          `uvm_warning(
            "SB_RDATA_EMPTY",
            $sformatf(
              "[target %0d] exp_rd_wr_data queue too small",
              tgt_idx
            )
          )

        end

        if (
          exp_val ==
          tgt.readData[i][7:0]
        ) begin

          `uvm_info(
            "SB_RDATA_MATCH",
            $sformatf(
              "[target %0d] readData[%0d]: expected 0x%0x got 0x%0x PASS",
              tgt_idx,
              i,
              exp_val,
              tgt.readData[i][7:0]
            ),
            UVM_MEDIUM
          )

          read_pass++;

        end
        else begin

          `uvm_error(
            "SB_RDATA_MISMATCH",
            $sformatf(
              "[target %0d] readData[%0d]: expected 0x%0x got 0x%0x FAIL",
              tgt_idx,
              i,
              exp_val,
              tgt.readData[i][7:0]
            )
          )

          read_fail++;

        end

      end

    end

    exp_rd_wr_data.delete();

  end

endtask : compare_with_target


//--------------------------------------------------------------------------------------------
// Check Phase
//--------------------------------------------------------------------------------------------

function void i3c_scoreboard::check_phase(
  uvm_phase phase
);

  super.check_phase(phase);

  `uvm_info(
    "SB_SUMMARY",
    $sformatf({
      "\n============= SCOREBOARD SUMMARY =============\n",
      "  APB transactions seen      : %0d\n",
      "  I3C target transactions    : %0d\n",
      "  -- SDR --\n",
      "  Write byte pass / fail     : %0d / %0d\n",
      "  Read  byte pass / fail     : %0d / %0d\n",
      "  -- DAA --\n",
      "  Devices seen               : %0d / %0d expected\n",
      "  Dyn address pass / fail    : %0d / %0d\n",
      "  Parity/ACK  pass / fail    : %0d / %0d\n",
      "=============================================="
    },
    apb_tx_count,
    target_tx_count,
    write_pass,
    write_fail,
    read_pass,
    read_fail,
    daa_devices_seen,
    i3c_env_cfg_h.no_of_daa_devices,
    daa_addr_pass,
    daa_addr_fail,
    daa_parity_pass,
    daa_parity_fail
    ),
    UVM_NONE
  )

  //------------------------------------------------------------------------------------------
  // SDR error flags
  //------------------------------------------------------------------------------------------

  if (write_fail != 0)

    `uvm_error(
      "SB_SUMMARY",
      $sformatf(
        "%0d write data mismatch(es)",
        write_fail
      )
    )

  if (read_fail != 0)

    `uvm_error(
      "SB_SUMMARY",
      $sformatf(
        "%0d read data mismatch(es)",
        read_fail
      )
    )

  //------------------------------------------------------------------------------------------
  // DAA count check
  //------------------------------------------------------------------------------------------

  if (
    i3c_env_cfg_h.has_daa &&
    daa_devices_seen !=
    i3c_env_cfg_h.no_of_daa_devices
  )

    `uvm_error(
      "SB_SUMMARY",
      $sformatf(
        "DAA device count: expected %0d, saw %0d",
        i3c_env_cfg_h.no_of_daa_devices,
        daa_devices_seen
      )
    )

  //------------------------------------------------------------------------------------------
  // DAA address error flags
  //------------------------------------------------------------------------------------------

  if (daa_addr_fail != 0)

    `uvm_error(
      "SB_SUMMARY",
      $sformatf(
        "%0d DAA dynamic address mismatch(es)",
        daa_addr_fail
      )
    )

  if (daa_parity_fail != 0)

    `uvm_error(
      "SB_SUMMARY",
      $sformatf(
        "%0d DAA parity/ACK failure(s)",
        daa_parity_fail
      )
    )

  //------------------------------------------------------------------------------------------
  // DAA unique dynamic address check
  //------------------------------------------------------------------------------------------

  if (i3c_env_cfg_h.has_daa) begin

    for (
      int i = 0;
      i < i3c_env_cfg_h.no_of_targets;
      i++
    ) begin

      for (
        int j = i + 1;
        j < i3c_env_cfg_h.no_of_targets;
        j++
      ) begin

        if (
          i3c_env_cfg_h.i3c_target_agent_cfg_h[i].targetAddress ==
          i3c_env_cfg_h.i3c_target_agent_cfg_h[j].targetAddress
        )

          `uvm_error(
            "SB_DAA_DUPLICATE_ADDR",
            $sformatf(
              "Targets %0d and %0d have the same dynamic address 0x%0h",
              i,
              j,
              i3c_env_cfg_h.i3c_target_agent_cfg_h[i].targetAddress
            )
          )

      end

    end

  end

  //------------------------------------------------------------------------------------------
  // DAA unique PID check
  //------------------------------------------------------------------------------------------

  if (i3c_env_cfg_h.has_daa) begin

    for (
      int i = 0;
      i < i3c_env_cfg_h.no_of_targets;
      i++
    ) begin

      for (
        int j = i + 1;
        j < i3c_env_cfg_h.no_of_targets;
        j++
      ) begin

        if (
          i3c_env_cfg_h.i3c_target_agent_cfg_h[i].pid ==
          i3c_env_cfg_h.i3c_target_agent_cfg_h[j].pid
        )

          `uvm_error(
            "SB_DAA_DUPLICATE_PID",
            $sformatf(
              "Targets %0d and %0d have the same PID 0x%0h (arb broken)",
              i,
              j,
              i3c_env_cfg_h.i3c_target_agent_cfg_h[i].pid
            )
          )

      end

    end

  end

  //------------------------------------------------------------------------------------------
  // Per-slave FIFO drain check
  //------------------------------------------------------------------------------------------

  foreach (target_analysis_fifo[i]) begin

    if (
      target_analysis_fifo[i].size() != 0
    )

      `uvm_error(
        "SB_SUMMARY",
        $sformatf(
          "target_analysis_fifo[%0d] not empty: %0d leftover packet(s)",
          i,
          target_analysis_fifo[i].size()
        )
      )

  end

  //------------------------------------------------------------------------------------------
  // IBI summary
  //------------------------------------------------------------------------------------------

  `uvm_info(
    "SB_SUMMARY",
    $sformatf({
      "\n============= IBI SUMMARY =============\n",
      "  IBI pass / fail            : %0d / %0d\n",
      "========================================"
    },
    ibi_pass,
    ibi_fail),
    UVM_NONE
  )

  if (ibi_fail != 0)

    `uvm_error(
      "SB_SUMMARY",
      $sformatf(
        "%0d IBI failure(s)",
        ibi_fail
      )
    )

  //------------------------------------------------------------------------------------------
  // Per-slave IBI FIFO drain check
  //------------------------------------------------------------------------------------------

  foreach (ibi_analysis_fifo[i]) begin

    if (
      ibi_analysis_fifo[i].size() != 0
    )

      `uvm_error(
        "SB_SUMMARY",
        $sformatf(
          "ibi_analysis_fifo[%0d] not empty: %0d leftover packet(s)",
          i,
          ibi_analysis_fifo[i].size()
        )
      )

  end

  //------------------------------------------------------------------------------------------
  // APB FIFO drain check
  //------------------------------------------------------------------------------------------

  if (
    apb_analysis_fifo.size() != 0
  )

    `uvm_error(
      "SB_SUMMARY",
      $sformatf(
        "APB FIFO not empty: %0d leftover packet(s)",
        apb_analysis_fifo.size()
      )
    )

  `uvm_info(
    "SB_SUMMARY",
    "check_phase complete",
    UVM_LOW
  )

endfunction : check_phase

`endif
