module i3c_bit_engine (
  input   wire        clk,
  input   wire        rst_n,
  input  wire         last_byte,
  input   wire        valid,
  input   wire        rd_wr,
  input   wire  [7:0] tx_data,
  output  reg   [7:0] rx_data,
  input   wire        arb_mode,
  input   wire        s_r,
  input   wire        push_pull,
  input   wire        shift_hold,
  input   wire        scl_i,
  input   wire        sda_i,
  output  reg         sda_o,
  output  reg         sda_oe,
  output  reg         busy,
  output  reg         nack,
  output  wire        txn_done,
  output  reg         start_done,
  output  reg         stop_done,
  output  reg       parity_error,
  output  reg         arbitration_lost,
  output  reg         pid_done,
  output  reg         shift_done,
  input   wire        ibi_adrs_active,
  input   wire        ibi_active,
  output  reg         ibi_tbit,
  input   wire        hotjoin_req,
  input   wire        valid_adrs,
  output reg        ibi_addr_cap_en,
  output reg [6:0]  ibi_addr_cap,
  input  wire        ibi_ack_ok
 );
localparam [2:0]
  IDLE  = 3'd0,
  START = 3'd1,
  SHIFT = 3'd2,
  ACK   = 3'd3,
  WAIT  = 3'd4,
  STOP  = 3'd5,
  PID_SHIFT = 3'd6;
reg [2:0] state, next;
reg [7:0] shift_reg;
reg [2:0] bit_cnt;
reg [2:0] byte_cnt;
reg       s_o, s_oe;
reg       sr_latch;
reg       v_latch;
reg       ack_hold;
reg       ibi_ack_value;
reg       parity_reg;
reg       par_hold;
reg   scl_q, scl_qq;
wire  scl_rise = (scl_q == 1'b1) && (scl_qq == 1'b0);
wire  scl_fall = (scl_q == 1'b0) && (scl_qq == 1'b1);
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    scl_q  <= 1'b1;
    scl_qq <= 1'b1;
     ibi_tbit <= 1'b0;
  end else begin
    scl_q  <= scl_i;
    scl_qq <= scl_q;
  end
end
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    v_latch <= 1'b0;
  else begin
    if (valid && !busy) v_latch <= 1'b1;
    else if (scl_fall)  v_latch <= 1'b0;
    else                v_latch <= v_latch;
  end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ack_hold      <= 1'b0;
        ibi_ack_value <= 1'b1;
    end
    else if (state == ACK && scl_rise && ibi_active && ibi_adrs_active) begin
        ack_hold      <= 1'b1;
        ibi_ack_value <= (shift_reg[7:1] == 7'h02);
    end
    else if (ack_hold && scl_fall) begin
        ack_hold <= 1'b0;
    end
end
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    par_hold <= 1'b0;
  else if (state == ACK && !rd_wr && push_pull)
    par_hold <= 1'b1;
  else if (scl_fall || state == STOP || state == IDLE)
    par_hold <= 1'b0;
end
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    pid_done <= 1'b0;
  else begin
    if (state == PID_SHIFT && scl_fall && bit_cnt == 0 && byte_cnt == 3'd5)
      pid_done <= 1'b1;
    else if (state == WAIT)
      pid_done <= 1'b0;
  end
end
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    ibi_addr_cap_en <= 1'b0;
    ibi_addr_cap    <= 7'd0;
  end else begin
    ibi_addr_cap_en <= 1'b0;
    if (state == SHIFT && rd_wr && ibi_adrs_active &&
        bit_cnt == 3'd0 && scl_rise) begin
      ibi_addr_cap_en <= 1'b1;
      ibi_addr_cap    <= {shift_reg[6:0]};
    end
  end
end
always @ (posedge clk or negedge rst_n) begin
  if (!rst_n) state <= IDLE;
  else      state <= next;
end
always @ (*) begin
  if (arb_mode) next = WAIT;
  else begin
    case (state)
      IDLE   : next = valid && !busy ? START : IDLE;
       START : next = scl_fall ?
              (shift_hold && rd_wr) ? PID_SHIFT : SHIFT : START;
       PID_SHIFT: begin
        if (bit_cnt==0 && byte_cnt==3'd5 && scl_fall)
          next = ACK;
        else
          next = PID_SHIFT;
      end
      SHIFT  : next =  (bit_cnt == 0) && scl_fall ? ACK   : SHIFT;
      ACK    : next = scl_rise ? WAIT  : ACK;
      WAIT: begin
          if (hotjoin_req)
               next = STOP;
          else if (pid_done)
            next = STOP;
          else if (shift_hold && rd_wr)
            next = PID_SHIFT;
          else if (s_r)
            next = IDLE;
         else if (valid_adrs &&ibi_active && scl_fall)
            next = STOP;
          else if (v_latch && scl_fall)
            next = SHIFT;
          else if (!v_latch && scl_fall)
            next = STOP;
          else
            next = WAIT;
        end
      STOP   : next = stop_done ? IDLE  : STOP;
      default: next = IDLE;
    endcase
  end
end
always @ * begin
  if (push_pull) begin
    case (state)
      IDLE   : {sda_oe, sda_o} = 2'b01;
      START  : {sda_oe, sda_o} = {s_oe, s_o};
      SHIFT,
      PID_SHIFT  : {sda_oe, sda_o} = rd_wr ? 2'b01 : {1'b1, shift_reg[7]};
      ACK: begin
      if(!rd_wr)
        {sda_oe,sda_o} = {1'b1, parity_reg};
      else
        {sda_oe,sda_o} = {1'b1, last_byte};
      end
      WAIT: begin
      if (par_hold && !rd_wr)
        {sda_oe, sda_o} = {1'b1, parity_reg};
      else
        {sda_oe, sda_o} = 2'b01;
      end
      STOP   : {sda_oe, sda_o} = {s_oe, s_o};
      default: {sda_oe, sda_o} = 2'b01;
    endcase
  end else begin
    sda_o = 1'b0;
    case (state)
      IDLE   : sda_oe          = 1'b0;
      START  : {sda_oe, sda_o} = {s_oe, s_o};
      SHIFT,
      PID_SHIFT  : sda_oe          = rd_wr ? 1'b0 : ~shift_reg[7];
      ACK: begin
      if (rd_wr) begin
         if (ibi_active && ibi_adrs_active) begin
            if (ibi_ack_ok || shift_reg[7:1] == 7'h02)
                sda_oe = 1'b1;
            else
                sda_oe = 1'b0;
        end
        else if (ibi_active && !ibi_adrs_active) begin
              sda_oe = 1'b0;
        end
            else begin
              sda_oe = 1'b1;
        end
    end
     else begin
        sda_oe = 1'b0;
      end
   end
    WAIT: begin
    if (ack_hold && ibi_active) begin
        if (ibi_ack_value || ibi_ack_ok)
            sda_oe = 1'b1;
        else
            sda_oe = 1'b0;
    end
    else if (ibi_active && !ibi_tbit) begin
        sda_oe = 1'b1;
      end
    else begin
        sda_oe = 1'b0;
    end
    end
      STOP   : {sda_oe, sda_o} = {s_oe, s_o};
      default: {sda_oe, sda_o} = 2'b01;
    endcase
  end
end
always @ (posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    bit_cnt   <= 'b0;
    sr_latch  <= 'b0;
    shift_reg <= 'b0;
    busy      <= 'b0;
    nack      <= 'b0;
    rx_data   <= 'b0;
    start_done<= 'b0;
    stop_done <= 'b0;
    s_oe      <= 'b0;
    s_o       <= 1'b1;
    shift_done<=1'b0;
   parity_error     <= 1'b0;
   arbitration_lost <= 1'b0;
   byte_cnt <= 3'd0;
   parity_reg <='b0;
  end else begin
    case (state)
      IDLE   : begin
      shift_done<=1'b0;
    parity_error     <= 1'b0;
    arbitration_lost <= 1'b0;
      bit_cnt   <= 3'd7;
      byte_cnt <= 3'd0;
      shift_reg <= rd_wr ? 8'b0 : tx_data;
      if (!rd_wr)
         parity_reg <= ^tx_data;
      busy <= valid;
      start_done<= valid ? 1'b1 : 1'b0;
      stop_done <= 1'b0;
      if (sr_latch) begin
          s_o     <= 1'b1;
          s_oe    <= 1'b1;
      end else begin
          s_o     <= 1'b1;
          s_oe    <= 1'b0;
      end
      end
      START  : begin
        busy <= 1'b1;
        s_o  <= sda_o;
        s_oe <= sda_oe;
        if (scl_i) begin
          s_o  <= 1'b0;
          s_oe <= 1'b1;
        end
      end
      SHIFT  : begin
        busy <= 1'b1;
        sr_latch    <= 1'b0;
       if (!rd_wr && sda_oe && sda_o && !sda_i)
          arbitration_lost <= 1'b1;
        if (scl_fall) begin
            bit_cnt   <= bit_cnt == 0 ? 3'd7 : bit_cnt - 1'b1;
        end
        if (rd_wr && scl_rise) begin
            shift_reg <= {shift_reg[6:0], sda_i};
        end else if (!rd_wr && scl_fall) begin
            shift_reg <= {shift_reg[6:0], 1'b0};
         end
      end
       PID_SHIFT: begin
        busy <= 1'b1;
        shift_done<=1'b0;
        if (rd_wr && scl_rise)
          shift_reg <= {shift_reg[6:0], sda_i};
        if (scl_fall) begin
          if (bit_cnt == 0) begin
            bit_cnt <= 3'd7;
            rx_data <= {shift_reg[6:0], sda_i};
            shift_reg<='b0;
            shift_done<=1'b1;
            byte_cnt <= byte_cnt + 1;
          end else begin
            bit_cnt <= bit_cnt - 1;
          end
        end
      end
      ACK: begin
        busy <= 1'b1;
        if (push_pull) begin
          if (!rd_wr && scl_rise) begin
              parity_error <= (sda_i != parity_reg);
              nack <= 1'b0;
          end
          else if (rd_wr && scl_rise) begin
              rx_data <= shift_reg;
              parity_error <= 1'b0;
          end
        end
        else begin
           if (!rd_wr && scl_rise)
              nack <= sda_i;
           else if (rd_wr && scl_rise) begin
              rx_data <= shift_reg;
               ibi_tbit  <= sda_i;
           end
        end
   end
      WAIT   : begin
        if (scl_fall) nack <= 1'b0;
        bit_cnt   <= 3'd7;
        shift_reg <= rd_wr   ? 8'b0 : tx_data;
        busy       <= v_latch;
        sr_latch  <= s_r     ? 1'b1 : sr_latch;
         if (!rd_wr && scl_fall)
        parity_reg <= ^tx_data;
      end
      STOP   : begin
      ibi_tbit<=1'b0;
      parity_reg<=1'b0;
      nack      <=1'b0;
        busy <= 1'b0;
        s_oe <= 1'b1;
        if (!scl_i) s_o <= 1'b0;
        else begin
          s_o       <= 1'b1;
          stop_done <= 1'b1;
        end
      end
      default: begin
        bit_cnt   <= bit_cnt;
        shift_reg <= shift_reg;
        busy      <= busy;
        nack      <= nack;
        s_o       <= sda_o;
        s_oe      <= sda_oe;
        stop_done <= 1'b0;
         start_done<=1'b0;
      end
    endcase
  end
end
assign txn_done = (state == WAIT) && !v_latch;
endmodule

