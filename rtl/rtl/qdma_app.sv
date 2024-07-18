`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/05/2024 02:13:35 AM
// Design Name: 
// Module Name: qdma_app
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


module qdma_app #(
    parameter DATA_WIDTH        = 256,
    parameter CRC_WIDTH         = 32,
    parameter QID_WIDTH         = 11,
    parameter VIP2DUT_WORDS_NUM = 16,
    parameter DUT2VIP_WORDS_NUM = 16,
    parameter DEBUG_DUT_TEST    = 1
)(
    input logic clk,
    input logic rst_n,
    
    // H2C AXI-Stream
    input logic [DATA_WIDTH-1:0]    m_axis_h2c_tdata,
    input logic [CRC_WIDTH-1:0]     m_axis_h2c_tcrc,
    input logic [QID_WIDTH-1:0]     m_axis_h2c_tuser_qid,
    input logic [2:0]               m_axis_h2c_tuser_port_id,
    input logic                     m_axis_h2c_tuser_err,
    input logic [31:0]              m_axis_h2c_tuser_mdata,
    input logic [5:0]               m_axis_h2c_tuser_mty,
    input logic                     m_axis_h2c_tuser_zero_byte,
    input logic                     m_axis_h2c_tvalid,
    input logic                     m_axis_h2c_tlast,
    output logic                    m_axis_h2c_tready,
    
    // C2H AXI-Stream
    output logic [DATA_WIDTH-1:0]   s_axis_c2h_tdata,
    output logic [CRC_WIDTH-1:0]    s_axis_c2h_tcrc,
    output logic                    s_axis_c2h_ctrl_marker,
    output logic [2:0]              s_axis_c2h_ctrl_port_id,
    output logic [6:0]              s_axis_c2h_ctrl_ecc,
    output logic [15:0]             s_axis_c2h_ctrl_len,
    output logic [QID_WIDTH-1:0]    s_axis_c2h_ctrl_qid,
    output logic                    s_axis_c2h_ctrl_has_cmpt,
    output logic [5:0]              s_axis_c2h_mty,
    output logic                    s_axis_c2h_tvalid,
    output logic                    s_axis_c2h_tlast,
    input logic                     s_axis_c2h_tready,

    // C2H CMPT AXI-Stream
    output logic [511:0]            s_axis_c2h_cmpt_tdata,
    output logic [1:0]              s_axis_c2h_cmpt_size,
    output logic [15:0]             s_axis_c2h_cmpt_dpar,
    output logic                    s_axis_c2h_cmpt_tvalid,
    output logic [10:0]             s_axis_c2h_cmpt_ctrl_qid,
    output logic [1:0]              s_axis_c2h_cmpt_ctrl_cmpt_type,
    output logic [15:0]             s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id,
    output logic                    s_axis_c2h_cmpt_ctrl_marker,
    output logic                    s_axis_c2h_cmpt_ctrl_user_trig,
    output logic                    s_axis_c2h_cmpt_ctrl_no_wrb_marker,
    output logic [2:0]              s_axis_c2h_cmpt_ctrl_col_idx,
    output logic [2:0]              s_axis_c2h_cmpt_ctrl_err_idx,
    output logic [2:0]              s_axis_c2h_cmpt_ctrl_port_id,
    input logic                     s_axis_c2h_cmpt_tready
);

localparam VIP2DUT_WIDTH = DATA_WIDTH * VIP2DUT_WORDS_NUM;
localparam DUT2VIP_WIDTH = DATA_WIDTH * DUT2VIP_WORDS_NUM;

logic ctrl_h2c_en;
logic ctrl_h2c_pkt_done;

logic ctrl_c2h_capture_ff;
logic ctrl_c2h_capture_next;

logic dut_clk_en_ff;
logic dut_clk_en_next;
logic dut_clk;

logic [VIP2DUT_WIDTH-1:0] vip2dut;
logic [DUT2VIP_WIDTH-1:0] dut2vip;

// H2C
h2c #(
    .DATA_WIDTH(DATA_WIDTH),
    .CRC_WIDTH(CRC_WIDTH),
    .QID_WIDTH(QID_WIDTH),
    .VIP2DUT_WORDS_NUM(VIP2DUT_WORDS_NUM)
)
h2c_inst (
    .clk(clk),
    .rst_n(rst_n),
    
    // Control
    .ctrl_h2c_en(ctrl_h2c_en),
    .ctrl_h2c_pkt_done(ctrl_h2c_pkt_done),
    
    // H2C AXI-S
    .h2c_tdata(m_axis_h2c_tdata),
    .h2c_tcrc(m_axis_h2c_tcrc),
    .h2c_tuser_qid(m_axis_h2c_tuser_qid),
    .h2c_tuser_err(m_axis_h2c_tuser_err),
    .h2c_tuser_mdata(m_axis_h2c_tuser_mdata),
    .h2c_tuser_mty(m_axis_h2c_tuser_mty),
    .h2c_tuser_zero_byte(m_axis_h2c_tuser_zero_byte),
    .h2c_tvalid(m_axis_h2c_tvalid),
    .h2c_tlast(m_axis_h2c_tlast),
    .h2c_tready(m_axis_h2c_tready),
    
    // to DUT
    .vip2dut(vip2dut)
);

// C2H
c2h #(
    .DATA_WIDTH(DATA_WIDTH),
    .CRC_WIDTH(CRC_WIDTH),
    .QID_WIDTH(QID_WIDTH),
    .DUT2VIP_WORDS_NUM(DUT2VIP_WORDS_NUM)
)
c2h_inst (
    .clk(clk),
    .rst_n(rst_n),
    
    // Control
    .ctrl_c2h_capture(ctrl_c2h_capture_ff),
    
    // C2H AXI-S
    .c2h_tdata(s_axis_c2h_tdata),
    .c2h_tcrc(s_axis_c2h_tcrc),
    .c2h_ctrl_marker(s_axis_c2h_ctrl_marker),
    .c2h_ctrl_port_id(s_axis_c2h_ctrl_port_id),
    .c2h_ctrl_ecc(s_axis_c2h_ctrl_ecc),
    .c2h_ctrl_len(s_axis_c2h_ctrl_len),
    .c2h_ctrl_qid(s_axis_c2h_ctrl_qid),
    .c2h_ctrl_has_cmpt(s_axis_c2h_ctrl_has_cmpt),
    .c2h_mty(s_axis_c2h_mty),
    .c2h_tvalid(s_axis_c2h_tvalid),
    .c2h_tlast(s_axis_c2h_tlast),
    .c2h_tready(s_axis_c2h_tready),
    
    // C2H CMPT AXI-S
    .c2h_cmpt_tdata(s_axis_c2h_cmpt_tdata),
    .c2h_cmpt_size(s_axis_c2h_cmpt_size),
    .c2h_cmpt_dpar(s_axis_c2h_cmpt_dpar),
    .c2h_cmpt_tvalid(s_axis_c2h_cmpt_tvalid),
    .c2h_cmpt_ctrl_qid(s_axis_c2h_cmpt_ctrl_qid),
    .c2h_cmpt_ctrl_cmpt_type(s_axis_c2h_cmpt_ctrl_cmpt_type),
    .c2h_cmpt_ctrl_wait_pld_pkt_id(s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id),
    .c2h_cmpt_ctrl_port_id(s_axis_c2h_cmpt_ctrl_port_id),
    .c2h_cmpt_ctrl_marker(s_axis_c2h_cmpt_ctrl_marker),
    .c2h_cmpt_ctrl_user_trig(s_axis_c2h_cmpt_ctrl_user_trig),
    .c2h_cmpt_ctrl_col_idx(s_axis_c2h_cmpt_ctrl_col_idx),
    .c2h_cmpt_ctrl_err_idx(s_axis_c2h_cmpt_ctrl_err_idx),
    .c2h_cmpt_tready(s_axis_c2h_cmpt_tready),
    .c2h_cmpt_ctrl_no_wrb_marker(s_axis_c2h_cmpt_ctrl_no_wrb_marker),
    
    // from DUT
    .dut2vip(dut2vip)
);

// DUT clock gating
BUFGCE
#(
    .CE_TYPE("SYNC")
)
BUFGCE_vip_clk_inst
(
    .O(dut_clk),
    .CE(dut_clk_en_ff),
    .I(clk)
);

// H2C enable
// We are ready to accept packets as soon clocking is done
assign ctrl_h2c_en = ~dut_clk_en_ff & ~ctrl_c2h_capture_ff;

// Clock gating enable
// 1 beat delay from H2C pkt_done
assign dut_clk_en_next = ctrl_h2c_pkt_done;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        dut_clk_en_ff <= 0;
    end
    else begin
        dut_clk_en_ff <= dut_clk_en_next;
    end
end

// Capture
// 1 beat delay from clocking enable
assign ctrl_c2h_capture_next = dut_clk_en_ff;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        ctrl_c2h_capture_ff <= 0;
    end
    else begin
        ctrl_c2h_capture_ff <= ctrl_c2h_capture_next;
    end
end

/* -------------------------------- */
/* YOUR DUT WRAPPER INSTANTIATION GOES HERE */
/* -------------------------------- */

// NOTE: use gated dut_clk signal and rst_n AXI reset

// dut_wrapper
// #(
//     .IN_BUS_WIDTH(DATA_WIDTH * VIP2DUT_WORDS_NUM),
//     .OUT_BUS_WIDTH(DATA_WIDTH * DUT2VIP_WORDS_NUM)
// )
// dut_test_i
// (
//     .clk (dut_clk),
//     .rst_n(rst_n),
//     .in  (vip2dut),
//     .out (dut2vip)
// );

generate
    if(DEBUG_DUT_TEST)
        dut_test
        #(
            .SIG_WIDTH(DATA_WIDTH * VIP2DUT_WORDS_NUM)
        )
        dut_test_i
        (
            .clk (dut_clk),
            .rst_n(rst_n),
            .in  (vip2dut),
            .out (dut2vip)
        );
endgenerate

endmodule
