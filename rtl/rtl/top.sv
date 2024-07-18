`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/26/2024 01:38:23 AM
// Design Name: 
// Module Name: top
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

module top #(
    parameter PL_LINK_CAP_MAX_LINK_WIDTH    = 8,    // 1 - X1; 2 - X2; 4 - X4; 8 - X8
    parameter PL_LINK_CAP_MAX_LINK_SPEED    = 4,    // 1 - GEN1; 2 - GEN2; 4 - GEN3
    parameter C_DATA_WIDTH                  = 256,
    parameter VIP2DUT_WORDS_NUM             = 4,
    parameter DUT2VIP_WORDS_NUM             = 4,
    parameter DEBUG_DUT_TEST                = 1
) (
    // PCIe RX/TX
    output logic    [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]   pci_exp_txp,
    output logic    [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]   pci_exp_txn,
    input logic     [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]   pci_exp_rxp,
    input logic     [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]   pci_exp_rxn,

    // System clock & reset
    input logic     sys_clk_p,
    input logic     sys_clk_n,
    input logic     sys_rst_n
);

// Hardcoded params
localparam QID_WIDTH    = 11;
localparam TM_DSC_BITS  = 16;

// Local Parameters derived from user selection
localparam CRC_WIDTH    = 32;

// System interace
logic sys_clk;
logic sys_clk_gt;
logic sys_rst_n_c;

// AXI interface
logic axi_aclk;
logic axi_aresetn;

// AXIS H2C
logic [C_DATA_WIDTH-1:0]    m_axis_h2c_tdata;
logic [CRC_WIDTH-1:0]       m_axis_h2c_tcrc;
logic [QID_WIDTH-1:0]       m_axis_h2c_tuser_qid;
logic [2:0]                 m_axis_h2c_tuser_port_id;
logic                       m_axis_h2c_tuser_err;
logic [31:0]                m_axis_h2c_tuser_mdata;
logic [5:0]                 m_axis_h2c_tuser_mty;
logic                       m_axis_h2c_tuser_zero_byte;
logic                       m_axis_h2c_tvalid;
logic                       m_axis_h2c_tlast;
logic                       m_axis_h2c_tready;

// AXIS C2H
logic [C_DATA_WIDTH-1:0]    s_axis_c2h_tdata;
logic [CRC_WIDTH-1:0]       s_axis_c2h_tcrc;
logic                       s_axis_c2h_ctrl_marker;
logic [2:0]                 s_axis_c2h_ctrl_port_id;
logic [6:0]                 s_axis_c2h_ctrl_ecc;
logic [15:0]                s_axis_c2h_ctrl_len;
logic [QID_WIDTH-1:0]       s_axis_c2h_ctrl_qid;
logic                       s_axis_c2h_ctrl_has_cmpt;
logic [5:0]                 s_axis_c2h_mty;
logic                       s_axis_c2h_tvalid;
logic                       s_axis_c2h_tlast;
logic                       s_axis_c2h_tready;

// AXIS C2H CMPT
logic [511:0]               s_axis_c2h_cmpt_tdata;
logic [1:0]                 s_axis_c2h_cmpt_size;
logic [15:0]                s_axis_c2h_cmpt_dpar;
logic                       s_axis_c2h_cmpt_tvalid;
logic [QID_WIDTH-1:0]       s_axis_c2h_cmpt_ctrl_qid;
logic [1:0]                 s_axis_c2h_cmpt_ctrl_cmpt_type;
logic [15:0]                s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id;
logic [2:0]                 s_axis_c2h_cmpt_ctrl_port_id;
logic                       s_axis_c2h_cmpt_ctrl_marker;
logic                       s_axis_c2h_cmpt_ctrl_user_trig;
logic [2:0]                 s_axis_c2h_cmpt_ctrl_col_idx;
logic [2:0]                 s_axis_c2h_cmpt_ctrl_err_idx;
logic                       s_axis_c2h_cmpt_tready;
logic                       s_axis_c2h_cmpt_ctrl_no_wrb_marker;

// AXIS C2H status
logic                       axis_c2h_status_drop;
logic                       axis_c2h_status_valid;
logic                       axis_c2h_status_cmp;
logic                       axis_c2h_status_error;
logic                       axis_c2h_status_last;
logic [10:0]                axis_c2h_status_qid;
logic                       axis_c2h_dmawr_cmp;

// QSTS (unused)
logic [7:0]                 qsts_out_op;
logic [63:0]                qsts_out_data;
logic [2:0]                 qsts_out_port_id;
logic [12:0]                qsts_out_qid;
logic                       qsts_out_vld;
logic                       qsts_out_rdy;

assign qsts_out_rdy = 1'b1;

// Traffic manager (unused)
logic                       tm_dsc_sts_vld;
logic [2:0]                 tm_dsc_sts_port_id;
logic                       tm_dsc_sts_qen;
logic                       tm_dsc_sts_byp;
logic                       tm_dsc_sts_dir;
logic                       tm_dsc_sts_mm;
logic                       tm_dsc_sts_error;
logic [QID_WIDTH-1:0]       tm_dsc_sts_qid;
logic [TM_DSC_BITS-1:0]     tm_dsc_sts_avl;
logic                       tm_dsc_sts_qinv;
logic                       tm_dsc_sts_irq_arm;
logic                       tm_dsc_sts_rdy;
logic [15:0]                tm_dsc_sts_pidx;

assign tm_dsc_sts_rdy = 1'b1;

// Ref clock buffer
// See https://docs.amd.com/v/u/en-US/ug576-ultrascale-gth-transceivers
IBUFDS_GTE4 #(
    .REFCLK_HROW_CK_SEL(2'b00)
) refclk_ibuf (
    .CEB('0),
    .I(sys_clk_p),
    .IB(sys_clk_n),
    .O(sys_clk_gt),
    .ODIV2(sys_clk)
);

// Reset buffer
IBUF sys_reset_n_ibuf (
    .I(sys_rst_n),
    .O(sys_rst_n_c)
);
    
qdma_0 qdma_inst (
  .sys_clk(sys_clk),                                                            // input wire sys_clk
  .sys_clk_gt(sys_clk_gt),                                                      // input wire sys_clk_gt
  .sys_rst_n(sys_rst_n_c),                                                      // input wire sys_rst_n
  
//  .user_lnk_up(user_lnk_up),                                                  // output wire user_lnk_up
  
  .pci_exp_txp(pci_exp_txp),                                                    // output wire [7 : 0] pci_exp_txp
  .pci_exp_txn(pci_exp_txn),                                                    // output wire [7 : 0] pci_exp_txn
  .pci_exp_rxp(pci_exp_rxp),                                                    // input wire [7 : 0] pci_exp_rxp
  .pci_exp_rxn(pci_exp_rxn),                                                    // input wire [7 : 0] pci_exp_rxn
  
  .axi_aclk(axi_aclk),                                                          // output wire axi_aclk
  .axi_aresetn(axi_aresetn),                                                    // output wire axi_aresetn
  
  .usr_irq_in_vld('0),                                                          // input wire usr_irq_in_vld
  .usr_irq_in_vec('0),                                                          // input wire [10 : 0] usr_irq_in_vec
  .usr_irq_in_fnc('0),                                                          // input wire [7 : 0] usr_irq_in_fnc
//  .usr_irq_out_ack(usr_irq_out_ack),                                          // output wire usr_irq_out_ack
//  .usr_irq_out_fail(usr_irq_out_fail),                                        // output wire usr_irq_out_fail
  
  .tm_dsc_sts_vld(tm_dsc_sts_vld),                                              // output wire tm_dsc_sts_vld
  .tm_dsc_sts_port_id(tm_dsc_sts_port_id),                                      // output wire [2 : 0] tm_dsc_sts_port_id
  .tm_dsc_sts_qen(tm_dsc_sts_qen),                                              // output wire tm_dsc_sts_qen
  .tm_dsc_sts_byp(tm_dsc_sts_byp),                                              // output wire tm_dsc_sts_byp
  .tm_dsc_sts_dir(tm_dsc_sts_dir),                                              // output wire tm_dsc_sts_dir
  .tm_dsc_sts_mm(tm_dsc_sts_mm),                                                // output wire tm_dsc_sts_mm
  .tm_dsc_sts_error(tm_dsc_sts_error),                                          // output wire tm_dsc_sts_error
  .tm_dsc_sts_qid(tm_dsc_sts_qid),                                              // output wire [10 : 0] tm_dsc_sts_qid
  .tm_dsc_sts_avl(tm_dsc_sts_avl),                                              // output wire [15 : 0] tm_dsc_sts_avl
  .tm_dsc_sts_qinv(tm_dsc_sts_qinv),                                            // output wire tm_dsc_sts_qinv
  .tm_dsc_sts_irq_arm(tm_dsc_sts_irq_arm),                                      // output wire tm_dsc_sts_irq_arm
  .tm_dsc_sts_rdy(tm_dsc_sts_rdy),                                              // input wire tm_dsc_sts_rdy
  .tm_dsc_sts_pidx(tm_dsc_sts_pidx),                                            // output wire [15 : 0] tm_dsc_sts_pidx
  
  .dsc_crdt_in_crdt('0),                                                        // input wire [15 : 0] dsc_crdt_in_crdt
  .dsc_crdt_in_qid('0),                                                         // input wire [10 : 0] dsc_crdt_in_qid
  .dsc_crdt_in_dir('0),                                                         // input wire dsc_crdt_in_dir
  .dsc_crdt_in_fence('0),                                                       // input wire dsc_crdt_in_fence
  .dsc_crdt_in_vld('0),                                                         // input wire dsc_crdt_in_vld
//  .dsc_crdt_in_rdy(dsc_crdt_in_rdy),                                          // output wire dsc_crdt_in_rdy
  
//  Unused
//  .m_axil_awaddr(m_axil_awaddr),                                              // output wire [31 : 0] m_axil_awaddr
//  .m_axil_awuser(m_axil_awuser),                                              // output wire [54 : 0] m_axil_awuser
//  .m_axil_awprot(m_axil_awprot),                                              // output wire [2 : 0] m_axil_awprot
//  .m_axil_awvalid(m_axil_awvalid),                                            // output wire m_axil_awvalid
  .m_axil_awready('0),                                                          // input wire m_axil_awready
//  .m_axil_wdata(m_axil_wdata),                                                // output wire [31 : 0] m_axil_wdata
//  .m_axil_wstrb(m_axil_wstrb),                                                // output wire [3 : 0] m_axil_wstrb
//  .m_axil_wvalid(m_axil_wvalid),                                              // output wire m_axil_wvalid
  .m_axil_wready('0),                                                           // input wire m_axil_wready
  .m_axil_bvalid('0),                                                           // input wire m_axil_bvalid
  .m_axil_bresp('0),                                                            // input wire [1 : 0] m_axil_bresp
//  .m_axil_bready(m_axil_bready),                                              // output wire m_axil_bready
//  .m_axil_araddr(m_axil_araddr),                                              // output wire [31 : 0] m_axil_araddr
//  .m_axil_aruser(m_axil_aruser),                                              // output wire [54 : 0] m_axil_aruser
//  .m_axil_arprot(m_axil_arprot),                                              // output wire [2 : 0] m_axil_arprot
//  .m_axil_arvalid(m_axil_arvalid),                                            // output wire m_axil_arvalid
  .m_axil_arready('0),                                                          // input wire m_axil_arready
  .m_axil_rdata('0),                                                            // input wire [31 : 0] m_axil_rdata
  .m_axil_rresp('0),                                                            // input wire [1 : 0] m_axil_rresp
  .m_axil_rvalid('0),                                                           // input wire m_axil_rvalid
//  .m_axil_rready(m_axil_rready),                                              // output wire m_axil_rready

  .m_axis_h2c_tdata(m_axis_h2c_tdata),                                          // output wire [255 : 0] m_axis_h2c_tdata
  .m_axis_h2c_tcrc(m_axis_h2c_tcrc),                                            // output wire [31 : 0] m_axis_h2c_tcrc
  .m_axis_h2c_tuser_qid(m_axis_h2c_tuser_qid),                                  // output wire [10 : 0] m_axis_h2c_tuser_qid
  .m_axis_h2c_tuser_port_id(m_axis_h2c_tuser_port_id),                          // output wire [2 : 0] m_axis_h2c_tuser_port_id
  .m_axis_h2c_tuser_err(m_axis_h2c_tuser_err),                                  // output wire m_axis_h2c_tuser_err
  .m_axis_h2c_tuser_mdata(m_axis_h2c_tuser_mdata),                              // output wire [31 : 0] m_axis_h2c_tuser_mdata
  .m_axis_h2c_tuser_mty(m_axis_h2c_tuser_mty),                                  // output wire [5 : 0] m_axis_h2c_tuser_mty
  .m_axis_h2c_tuser_zero_byte(m_axis_h2c_tuser_zero_byte),                      // output wire m_axis_h2c_tuser_zero_byte
  .m_axis_h2c_tvalid(m_axis_h2c_tvalid),                                        // output wire m_axis_h2c_tvalid
  .m_axis_h2c_tlast(m_axis_h2c_tlast),                                          // output wire m_axis_h2c_tlast
  .m_axis_h2c_tready(m_axis_h2c_tready),                                        // input wire m_axis_h2c_tready
  
  .s_axis_c2h_tdata(s_axis_c2h_tdata),                                          // input wire [255 : 0] s_axis_c2h_tdata
  .s_axis_c2h_tcrc(s_axis_c2h_tcrc),                                            // input wire [31 : 0] s_axis_c2h_tcrc
  .s_axis_c2h_ctrl_marker(s_axis_c2h_ctrl_marker),                              // input wire s_axis_c2h_ctrl_marker
  .s_axis_c2h_ctrl_port_id(s_axis_c2h_ctrl_port_id),                            // input wire [2 : 0] s_axis_c2h_ctrl_port_id
  .s_axis_c2h_ctrl_ecc(s_axis_c2h_ctrl_ecc),                                    // input wire [6 : 0] s_axis_c2h_ctrl_ecc
  .s_axis_c2h_ctrl_len(s_axis_c2h_ctrl_len),                                    // input wire [15 : 0] s_axis_c2h_ctrl_len
  .s_axis_c2h_ctrl_qid(s_axis_c2h_ctrl_qid),                                    // input wire [10 : 0] s_axis_c2h_ctrl_qid
  .s_axis_c2h_ctrl_has_cmpt(s_axis_c2h_ctrl_has_cmpt),                          // input wire s_axis_c2h_ctrl_has_cmpt
  .s_axis_c2h_mty(s_axis_c2h_mty),                                              // input wire [5 : 0] s_axis_c2h_mty
  .s_axis_c2h_tvalid(s_axis_c2h_tvalid),                                        // input wire s_axis_c2h_tvalid
  .s_axis_c2h_tlast(s_axis_c2h_tlast),                                          // input wire s_axis_c2h_tlast
  .s_axis_c2h_tready(s_axis_c2h_tready),                                        // output wire s_axis_c2h_tready
  
  .s_axis_c2h_cmpt_tdata(s_axis_c2h_cmpt_tdata),                                // input wire [511 : 0] s_axis_c2h_cmpt_tdata
  .s_axis_c2h_cmpt_size(s_axis_c2h_cmpt_size),                                  // input wire [1 : 0] s_axis_c2h_cmpt_size
  .s_axis_c2h_cmpt_dpar(s_axis_c2h_cmpt_dpar),                                  // input wire [15 : 0] s_axis_c2h_cmpt_dpar
  .s_axis_c2h_cmpt_tvalid(s_axis_c2h_cmpt_tvalid),                              // input wire s_axis_c2h_cmpt_tvalid
  .s_axis_c2h_cmpt_ctrl_qid(s_axis_c2h_cmpt_ctrl_qid),                          // input wire [10 : 0] s_axis_c2h_cmpt_ctrl_qid
  .s_axis_c2h_cmpt_ctrl_cmpt_type(s_axis_c2h_cmpt_ctrl_cmpt_type),              // input wire [1 : 0] s_axis_c2h_cmpt_ctrl_cmpt_type
  .s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id(s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id),  // input wire [15 : 0] s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id
  .s_axis_c2h_cmpt_ctrl_port_id(s_axis_c2h_cmpt_ctrl_port_id),                  // input wire [2 : 0] s_axis_c2h_cmpt_ctrl_port_id
  .s_axis_c2h_cmpt_ctrl_marker(s_axis_c2h_cmpt_ctrl_marker),                    // input wire s_axis_c2h_cmpt_ctrl_marker
  .s_axis_c2h_cmpt_ctrl_user_trig(s_axis_c2h_cmpt_ctrl_user_trig),              // input wire s_axis_c2h_cmpt_ctrl_user_trig
  .s_axis_c2h_cmpt_ctrl_col_idx(s_axis_c2h_cmpt_ctrl_col_idx),                  // input wire [2 : 0] s_axis_c2h_cmpt_ctrl_col_idx
  .s_axis_c2h_cmpt_ctrl_err_idx(s_axis_c2h_cmpt_ctrl_err_idx),                  // input wire [2 : 0] s_axis_c2h_cmpt_ctrl_err_idx
  .s_axis_c2h_cmpt_tready(s_axis_c2h_cmpt_tready),                              // output wire s_axis_c2h_cmpt_tready
  .s_axis_c2h_cmpt_ctrl_no_wrb_marker(s_axis_c2h_cmpt_ctrl_no_wrb_marker),      // input wire s_axis_c2h_cmpt_ctrl_no_wrb_marker

  .axis_c2h_status_drop(axis_c2h_status_drop),                                  // output wire axis_c2h_status_drop
  .axis_c2h_status_valid(axis_c2h_status_valid),                                // output wire axis_c2h_status_valid
  .axis_c2h_status_cmp(axis_c2h_status_cmp),                                    // output wire axis_c2h_status_cmp
  .axis_c2h_status_error(axis_c2h_status_error),                                // output wire axis_c2h_status_error
  .axis_c2h_status_last(axis_c2h_status_last),                                  // output wire axis_c2h_status_last
  .axis_c2h_status_qid(axis_c2h_status_qid),                                    // output wire [10 : 0] axis_c2h_status_qid
  .axis_c2h_dmawr_cmp(axis_c2h_dmawr_cmp),                                      // output wire axis_c2h_dmawr_cmp
  
  .soft_reset_n(1'b1),                                                          // input wire soft_reset_n
//  .phy_ready(phy_ready),                                                      // output wire phy_ready

  .qsts_out_op(qsts_out_op),                                                    // output wire [7 : 0] qsts_out_op
  .qsts_out_data(qsts_out_data),                                                // output wire [63 : 0] qsts_out_data
  .qsts_out_port_id(qsts_out_port_id),                                          // output wire [2 : 0] qsts_out_port_id
  .qsts_out_qid(qsts_out_qid),                                                  // output wire [12 : 0] qsts_out_qid
  .qsts_out_vld(qsts_out_vld),                                                  // output wire qsts_out_vld
  .qsts_out_rdy(qsts_out_rdy)                                                   // input wire qsts_out_rdy
);

qdma_app #(
    .DATA_WIDTH(C_DATA_WIDTH),
    .CRC_WIDTH(CRC_WIDTH),
    .QID_WIDTH(QID_WIDTH),
    .VIP2DUT_WORDS_NUM(VIP2DUT_WORDS_NUM),
    .DUT2VIP_WORDS_NUM(DUT2VIP_WORDS_NUM),
    .DEBUG_DUT_TEST(DEBUG_DUT_TEST)
) 
qdma_app_inst (
    .clk(axi_aclk),
    .rst_n(axi_aresetn),
    
    // H2C AXI-S
    .m_axis_h2c_tdata(m_axis_h2c_tdata),
    .m_axis_h2c_tcrc(m_axis_h2c_tcrc),
    .m_axis_h2c_tuser_qid(m_axis_h2c_tuser_qid),
    .m_axis_h2c_tuser_port_id(m_axis_h2c_tuser_port_id),
    .m_axis_h2c_tuser_err(m_axis_h2c_tuser_err),
    .m_axis_h2c_tuser_mdata(m_axis_h2c_tuser_mdata),
    .m_axis_h2c_tuser_mty(m_axis_h2c_tuser_mty),
    .m_axis_h2c_tuser_zero_byte(m_axis_h2c_tuser_zero_byte),
    .m_axis_h2c_tvalid(m_axis_h2c_tvalid),
    .m_axis_h2c_tlast(m_axis_h2c_tlast),
    .m_axis_h2c_tready(m_axis_h2c_tready),
    
    // C2H AXI-S
    .s_axis_c2h_tdata(s_axis_c2h_tdata),
    .s_axis_c2h_tcrc(s_axis_c2h_tcrc),
    .s_axis_c2h_ctrl_marker(s_axis_c2h_ctrl_marker),
    .s_axis_c2h_ctrl_port_id(s_axis_c2h_ctrl_port_id),
    .s_axis_c2h_ctrl_ecc(s_axis_c2h_ctrl_ecc),
    .s_axis_c2h_ctrl_len(s_axis_c2h_ctrl_len),
    .s_axis_c2h_ctrl_qid(s_axis_c2h_ctrl_qid),
    .s_axis_c2h_ctrl_has_cmpt(s_axis_c2h_ctrl_has_cmpt),
    .s_axis_c2h_mty(s_axis_c2h_mty),
    .s_axis_c2h_tvalid(s_axis_c2h_tvalid),
    .s_axis_c2h_tlast(s_axis_c2h_tlast),
    .s_axis_c2h_tready(s_axis_c2h_tready),
    
    // C2H CMPT AXI-S
    .s_axis_c2h_cmpt_tdata(s_axis_c2h_cmpt_tdata),
    .s_axis_c2h_cmpt_size(s_axis_c2h_cmpt_size),
    .s_axis_c2h_cmpt_dpar(s_axis_c2h_cmpt_dpar),
    .s_axis_c2h_cmpt_tvalid(s_axis_c2h_cmpt_tvalid),
    .s_axis_c2h_cmpt_ctrl_qid(s_axis_c2h_cmpt_ctrl_qid),
    .s_axis_c2h_cmpt_ctrl_cmpt_type(s_axis_c2h_cmpt_ctrl_cmpt_type),
    .s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id(s_axis_c2h_cmpt_ctrl_wait_pld_pkt_id),
    .s_axis_c2h_cmpt_ctrl_port_id(s_axis_c2h_cmpt_ctrl_port_id),
    .s_axis_c2h_cmpt_ctrl_marker(s_axis_c2h_cmpt_ctrl_marker),
    .s_axis_c2h_cmpt_ctrl_user_trig(s_axis_c2h_cmpt_ctrl_user_trig),
    .s_axis_c2h_cmpt_ctrl_col_idx(s_axis_c2h_cmpt_ctrl_col_idx),
    .s_axis_c2h_cmpt_ctrl_err_idx(s_axis_c2h_cmpt_ctrl_err_idx),
    .s_axis_c2h_cmpt_tready(s_axis_c2h_cmpt_tready),
    .s_axis_c2h_cmpt_ctrl_no_wrb_marker(s_axis_c2h_cmpt_ctrl_no_wrb_marker)
);
    
endmodule
