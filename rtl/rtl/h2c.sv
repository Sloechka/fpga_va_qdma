`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/05/2024 02:21:28 AM
// Design Name: 
// Module Name: h2c
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


module h2c #(
    parameter DATA_WIDTH        = 256,
    parameter CRC_WIDTH         = 32,
    parameter QID_WIDTH         = 11,
    parameter VIP2DUT_WORDS_NUM = 16
)(
    input logic                     clk,
    input logic                     rst_n,
    
    // Control
    input logic                     ctrl_h2c_en,
    output logic                    ctrl_h2c_pkt_done,
    
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
    
    // to DUT
    output logic [(DATA_WIDTH * VIP2DUT_WORDS_NUM - 1):0] vip2dut
);

logic handshake;
logic eop;

logic [$clog2(VIP2DUT_WORDS_NUM):0] beat_cntr_ff;
logic [$clog2(VIP2DUT_WORDS_NUM):0] beat_cntr_next;

logic [DATA_WIDTH-1:0] vip2dut_shreg_ff     [VIP2DUT_WORDS_NUM-1:0];
logic [DATA_WIDTH-1:0] vip2dut_shreg_next   [VIP2DUT_WORDS_NUM-1:0];
logic vip2dut_shreg_en;

// Packet logic
assign handshake = h2c_tvalid & h2c_tready;
assign eop = handshake & h2c_tlast;

assign ctrl_h2c_pkt_done = eop;

assign h2c_tready = ctrl_h2c_en;

// Beat counter
assign beat_cntr_next = handshake ? (h2c_tlast ? '0 : beat_cntr_ff + 1'b1) : beat_cntr_ff;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        beat_cntr_ff <= 0;
    end
    else begin
        beat_cntr_ff <= beat_cntr_next;
    end
end

// VIP2DUT shift register
assign vip2dut_shreg_en = handshake & (beat_cntr_ff < VIP2DUT_WORDS_NUM);

generate;
    assign vip2dut_shreg_next[0] = h2c_tdata;
    for (genvar i = 1; i < VIP2DUT_WORDS_NUM; i++) begin
      assign vip2dut_shreg_next[i] = vip2dut_shreg_ff[i-1];
    end
endgenerate;

always_ff @(posedge clk) begin
    if(vip2dut_shreg_en) begin
        vip2dut_shreg_ff <= vip2dut_shreg_next;
    end
end

generate;
    for(genvar i = 0; i < VIP2DUT_WORDS_NUM; i++) begin
        assign vip2dut[((i + 1) * DATA_WIDTH - 1):(i * DATA_WIDTH)] = vip2dut_shreg_ff[i];
    end
endgenerate;

endmodule
