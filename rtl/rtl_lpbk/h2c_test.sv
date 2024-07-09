`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/29/2024 03:21:12 PM
// Design Name: 
// Module Name: h2c_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module h2c_lbpk #(
    parameter DATA_WIDTH        = 256,
    parameter PKT_WORDS_LEN     = 8,
    parameter CRC_WIDTH         = 32,
    parameter QID_WIDTH         = 11
)(
    input logic                     clk,
    input logic                     rst_n,
    
    // Control
    output logic                    h2c_pkt_done,
    
    // H2C AXI-S
    input logic [DATA_WIDTH-1:0]    h2c_tdata,
    input logic [CRC_WIDTH-1:0]     h2c_tcrc,
    input logic [10:0]              h2c_tuser_qid,
    input logic                     h2c_tvalid,
    input logic                     h2c_tlast,
    
    input logic [2:0]               h2c_tuser_port_id,      // Unused
    input logic                     h2c_tuser_err,          // Unused
    input logic [31:0]              h2c_tuser_mdata,        // Unused
    input logic [5:0]               h2c_tuser_mty,          // Unused
    input logic                     h2c_tuser_zero_byte,    // Unused
    output logic                    h2c_tready,

    // FIFO ports
    output logic fifo_s_axis_tvalid,
    input logic fifo_s_axis_tready,
    output logic [DATA_WIDTH-1:0] fifo_s_axis_tdata,
    output logic fifo_s_axis_tlast
);

localparam PKT_LEN = PKT_WORDS_LEN * DATA_WIDTH;
localparam PKT_LEN_BYTES = PKT_LEN / 8;

logic handshake;
logic eop;
logic [$clog2(PKT_WORDS_LEN):0] beat_cntr_ff;
logic [$clog2(PKT_WORDS_LEN):0] beat_cntr_next;

// pkt
assign handshake = h2c_tvalid & h2c_tready;
assign eop = handshake & h2c_tlast;

assign h2c_pkt_done = eop;

assign fifo_s_axis_tvalid = h2c_tvalid;
assign fifo_s_axis_tdata = h2c_tdata;
assign fifo_s_axis_tlast = h2c_tlast;

assign h2c_tready = fifo_s_axis_tready;

// beat cntr
assign beat_cntr_next = handshake ? (h2c_tlast ? '0 : beat_cntr_ff + 1'b1) : beat_cntr_ff;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        beat_cntr_ff <= 0;
    end
    else begin
        beat_cntr_ff <= beat_cntr_next;
    end
end

endmodule
