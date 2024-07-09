`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/30/2024 03:20:42 AM
// Design Name: 
// Module Name: lpbk_app
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: for debug purposes only. Do not instatiate this module in release app.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module lpbk_app #(
    parameter DATA_WIDTH        = 256,
    parameter PKT_WORDS_LEN     = 8,
    parameter CRC_WIDTH         = 32,
    parameter QID_WIDTH         = 11
) (
    input logic clk,
    input logic rst_n,
    
    // H2C AXI-S
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
    
    // C2H AXI-S
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

    // C2H CMPT AXI-S
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
    
logic fifo_s_axis_tvalid;
logic fifo_s_axis_tready;
logic [DATA_WIDTH-1:0] fifo_s_axis_tdata;
logic fifo_s_axis_tlast;

logic fifo_m_axis_tvalid;
logic fifo_m_axis_tready;
logic [DATA_WIDTH-1:0] fifo_m_axis_tdata;
logic fifo_m_axis_tlast;

logic h2c_pkt_done;

h2c_lbpk #(
    .DATA_WIDTH(DATA_WIDTH),
    .PKT_WORDS_LEN(PKT_WORDS_LEN),
    .CRC_WIDTH(CRC_WIDTH),
    .QID_WIDTH(QID_WIDTH)
)
h2c_lbpk_inst (
    .clk(clk),
    .rst_n(rst_n),
    
    // Control
    .h2c_pkt_done(h2c_pkt_done),
    
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
    
    // FIFO
    .fifo_s_axis_tvalid(fifo_s_axis_tvalid),
    .fifo_s_axis_tready(fifo_s_axis_tready),
    .fifo_s_axis_tdata(fifo_s_axis_tdata),
    .fifo_s_axis_tlast(fifo_s_axis_tlast)
);

axis_data_fifo_0 lpbk_fifo(
    .s_axis_aresetn(rst_n),              // input wire s_axis_aresetn
    .s_axis_aclk(clk),                    // input wire s_axis_aclk
    .s_axis_tvalid(fifo_s_axis_tvalid),   // input wire s_axis_tvalid
    .s_axis_tready(fifo_s_axis_tready),   // output wire s_axis_tready
    .s_axis_tdata(fifo_s_axis_tdata),     // input wire [255 : 0] s_axis_tdata
    .s_axis_tlast(fifo_s_axis_tlast),     // input wire s_axis_tlast
    .m_axis_tvalid(fifo_m_axis_tvalid),   // output wire m_axis_tvalid
    .m_axis_tready(fifo_m_axis_tready),   // input wire m_axis_tready
    .m_axis_tdata(fifo_m_axis_tdata),     // output wire [255 : 0] m_axis_tdata
    .m_axis_tlast(fifo_m_axis_tlast)      // output wire m_axis_tlast
);

c2h_lpbk #(
    .DATA_WIDTH(DATA_WIDTH),
    .PKT_WORDS_LEN(PKT_WORDS_LEN),
    .CRC_WIDTH(CRC_WIDTH),
    .QID_WIDTH(QID_WIDTH)
)
c2h_lpbk_inst (
    .clk(clk),
    .rst_n(rst_n),
    
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
    
    // FIFO
    .fifo_m_axis_tvalid(fifo_m_axis_tvalid),
    .fifo_m_axis_tready(fifo_m_axis_tready),
    .fifo_m_axis_tdata(fifo_m_axis_tdata),
    .fifo_m_axis_tlast(fifo_m_axis_tlast)
);

endmodule
