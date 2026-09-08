`ifndef APB_I3C_WRAPPER_INCLUDED_
`define APB_I3C_WRAPPER_INCLUDED_
`include "apb_if.sv"
import apb_global_pkg::*;
module apb_i3c_wrapper(
    apb_if apb,

    output logic        wr_en,
    output logic        rd_en,
    output logic [6:0]  addrs,
    output logic [31:0] w_reg_data,
    output logic [7:0]  w_data,

    input  logic [31:0] rd_data,
    input  logic [7:0]  r_data
);

logic pready_r;

assign apb.pready  = pready_r;
assign apb.pslverr = 1'b0;

always_ff @(posedge apb.pclk or negedge apb.preset_n) begin
    if(!apb.preset_n) begin
        wr_en      <= 0;
        rd_en      <= 0;
        addrs      <= 0;
        w_reg_data <= 0;
        w_data     <= 0;
        apb.prdata <= 0;
        pready_r   <= 0;
    end
    else begin
        wr_en    <= 0;
        rd_en    <= 0;
        pready_r <= 0;

        if(apb.pselx[0] && apb.penable && !pready_r) begin
            addrs <= apb.paddr[6:0];

            if(apb.pwrite) begin
                wr_en      <= 1;
                w_reg_data <= apb.pwdata;
                w_data     <= apb.pwdata[7:0];
            end
            else begin
                rd_en <= 1;
                apb.prdata <= {24'b0, r_data};
            end

            pready_r <= 1;
        end
    end
end

endmodule
`endif

/*
`ifndef APB_IF_INCLUDED_
`define APB_IF_INCLUDED_
`include "apb_if.sv"
import apb_global_pkg::*;

module apb_i3c_wrapper(
    apb_if apb,
    output logic        wr_en,
    output logic        rd_en,
    output logic [6:0]  addrs,
    output logic [31:0] w_reg_data,
    output logic [7:0]  w_data,
    input  logic [31:0] rd_data,
    input  logic [7:0]  r_data
);

logic pready_r;
logic rd_en_r;
logic rd_en_rr;

assign apb.pready  = pready_r;
assign apb.pslverr = 1'b0;
assign apb.prdata  = {24'b0, r_data};  // combinational

always_ff @(posedge apb.pclk or negedge apb.preset_n) begin
    if(!apb.preset_n) begin
        wr_en      <= 0;
        rd_en      <= 0;
        rd_en_r    <= 0;
        rd_en_rr   <= 0;
        addrs      <= 0;
        w_reg_data <= 0;
        w_data     <= 0;
        pready_r   <= 0;
    end
    else begin
        wr_en    <= 0;
        rd_en    <= 0;
        rd_en_r  <= rd_en;
        rd_en_rr <= rd_en_r;
        pready_r <= 0;

        if(apb.pselx[0] && apb.penable && !pready_r
                        && !rd_en && !rd_en_r && !rd_en_rr) begin
            addrs <= apb.paddr[6:0];
            if(apb.pwrite) begin
                wr_en      <= 1;
                w_reg_data <= apb.pwdata;
                w_data     <= apb.pwdata[7:0];
                pready_r   <= 1;    // writes: 0 wait states
            end
            else begin
                rd_en <= 1;         // reads: start 2-cycle wait
            end
        end

        // pready always 2 cycles after rd_en
        // covers WDATAB(needs 1) and RDATAB(needs 2)
        if(rd_en_rr) begin
            pready_r <= 1;
        end
    end
end

always_ff @(posedge apb.pclk) begin
    $display("[%0t] WRAP_DBG: rd_en=%0b rd_en_r=%0b rd_en_rr=%0b pready=%0b r_data=%0h prdata=%0h",
              $time, rd_en, rd_en_r, rd_en_rr, pready_r, r_data, apb.prdata);
end
endmodule

`endif

*/
