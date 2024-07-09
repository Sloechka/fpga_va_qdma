`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/27/2024 06:06:31 AM
// Design Name: 
// Module Name: c2h
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


module c2h #(
    parameter DATA_WIDTH        = 256,
    parameter CRC_WIDTH         = 32,
    parameter QID_WIDTH         = 11,
    parameter DUT2VIP_WORDS_NUM = 16 
)(
    input logic                     clk,
    input logic                     rst_n,
    
    // Control
    input logic                     ctrl_c2h_capture,
    
    // C2H AXI-S
    output logic [DATA_WIDTH-1:0]   c2h_tdata,
    output logic                    c2h_tvalid,
    output logic                    c2h_tlast,
    
    output logic [15:0]             c2h_ctrl_len,
    output logic [10:0]             c2h_ctrl_qid,
    output logic                    c2h_ctrl_has_cmpt,
    
    output logic                    c2h_ctrl_marker,        // Unused
    output logic [2:0]              c2h_ctrl_port_id,       // Unused
    output logic [5:0]              c2h_mty,                // Unused
    output logic [CRC_WIDTH-1:0]    c2h_tcrc,               // Unused
    output logic [6:0]              c2h_ctrl_ecc,           // Unused
    
    input logic                     c2h_tready,
    
    // C2H CMPT
    output logic [511:0]            c2h_cmpt_tdata,
    output logic [1:0]              c2h_cmpt_size,
    output logic [15:0]             c2h_cmpt_dpar,
    output logic [10:0]             c2h_cmpt_ctrl_qid,
    output logic [1:0]              c2h_cmpt_ctrl_cmpt_type,
    output logic [15:0]             c2h_cmpt_ctrl_wait_pld_pkt_id,
    output logic                    c2h_cmpt_ctrl_marker,
    output logic                    c2h_cmpt_ctrl_user_trig,
    output logic                    c2h_cmpt_ctrl_no_wrb_marker,

    output logic [2:0]              c2h_cmpt_ctrl_col_idx,   // Unused
    output logic [2:0]              c2h_cmpt_ctrl_err_idx,   // Unused
    output logic [2:0]              c2h_cmpt_ctrl_port_id,   // Unused
   
    output logic                    c2h_cmpt_tvalid,
    input logic                     c2h_cmpt_tready,
    
    // from DUT
    input logic [(DATA_WIDTH * DUT2VIP_WORDS_NUM - 1):0] dut2vip
);

localparam [15:0] PKT_LEN_BYTES = DUT2VIP_WORDS_NUM * DATA_WIDTH / 8;   // 16 bits are reserved for packet length
                                                                        // see https://xilinx.github.io/dma_ip_drivers/master/QDMA/DPDK/html/qdma_usecases.html

logic handshake;
logic eop;
logic sop;

logic [$clog2(DUT2VIP_WORDS_NUM):0] beat_cntr_ff;
logic [$clog2(DUT2VIP_WORDS_NUM):0] beat_cntr_next;

logic [DATA_WIDTH-1:0] dut2vip_mda          [DUT2VIP_WORDS_NUM-1:0];
logic [DATA_WIDTH-1:0] dut2vip_shreg_ff     [DUT2VIP_WORDS_NUM-1:0];
logic [DATA_WIDTH-1:0] dut2vip_shreg_next   [DUT2VIP_WORDS_NUM-1:0];
logic dut2vip_shreg_en;

// C2H enbale
typedef enum {C2H_ACTIVE, C2H_IDLE} ctrl_c2h_state;
ctrl_c2h_state ctrl_c2h_state_ff;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        ctrl_c2h_state_ff <= C2H_IDLE;
    end
    else begin
        case(ctrl_c2h_state_ff)
            C2H_IDLE: begin
                if(ctrl_c2h_capture) begin
                    ctrl_c2h_state_ff <= C2H_ACTIVE;
                end
            end
            C2H_ACTIVE: begin
                if(eop) begin
                    ctrl_c2h_state_ff <= C2H_IDLE;
                end
            end
            default: begin
                ctrl_c2h_state_ff <= C2H_IDLE;
            end
        endcase
    end
end

// Packet logic
assign handshake = c2h_tvalid & c2h_tready;
assign sop = handshake & !beat_cntr_ff;
assign eop = handshake & (beat_cntr_ff == (DUT2VIP_WORDS_NUM - 1));

assign c2h_tvalid = (ctrl_c2h_state_ff == C2H_ACTIVE);
assign c2h_tdata = dut2vip_shreg_ff[DUT2VIP_WORDS_NUM - 1];
assign c2h_tlast = eop;

assign c2h_ctrl_qid = '0;
assign c2h_ctrl_len = PKT_LEN_BYTES;
assign c2h_ctrl_has_cmpt = 1'b1;

assign c2h_ctrl_marker = 0;
assign c2h_ctrl_port_id = '0;
assign c2h_mty = '0;
assign c2h_tcrc = '0;
assign c2h_ctrl_ecc = '0;

// Beat counter
assign beat_cntr_next = handshake ? (eop ? 1'b0 : (beat_cntr_ff + 1'b1)) : beat_cntr_ff;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        beat_cntr_ff <= '0;
    end
    else begin
        beat_cntr_ff <= beat_cntr_next;
    end
end

// DUT2VIP
// Unflatten dut2vip to MDA
generate;
    for(genvar i = 0; i < DUT2VIP_WORDS_NUM; i++) begin
        assign dut2vip_mda[i] = dut2vip[((i + 1) * DATA_WIDTH - 1):(i * DATA_WIDTH)];
    end
endgenerate;

// Capture & shift
generate;
    assign dut2vip_shreg_next[0] = dut2vip_mda[0];
    
    for(genvar i = 1; i < DUT2VIP_WORDS_NUM; i++) begin
        assign dut2vip_shreg_next[i] = ctrl_c2h_capture ? dut2vip_mda[i] : dut2vip_shreg_ff[i-1];  
    end
endgenerate;

// Shift register
assign dut2vip_shreg_en = ctrl_c2h_capture | handshake;

always_ff @(posedge clk) begin
    if(dut2vip_shreg_en) begin
        dut2vip_shreg_ff <= dut2vip_shreg_next;
    end
end

// CMPT
logic           cmpt_handshake;
logic [15:0]    pkt_cntr_ff;
logic [15:0]    pkt_cntr_next;

typedef enum {CMPT_DONE, CMPT_START} cmpt_state;
cmpt_state cmpt_state_ff;

assign cmpt_handshake = c2h_cmpt_tready & c2h_cmpt_tvalid;
assign c2h_cmpt_tdata = {PKT_LEN_BYTES, {4'b1000}};

assign c2h_cmpt_size                    = 2'b00;    // 2'b00: 8B completion
                                                    // 2'b01: 16B completion
                                                    // 2'b10: 32B completion.
                                                    // 2'b11: 64B completion
                                                    
assign c2h_cmpt_ctrl_cmpt_type          = 2'b11;    // 2'b00: NO_PLD_NO_WAIT
                                                    // 2'b01: NO_PLD_BUT_WAIT
                                                    // 2'b10: RESERVED
                                                    // 2'b11: HAS_PLD
                                                    
assign c2h_cmpt_ctrl_wait_pld_pkt_id    = pkt_cntr_ff;
assign c2h_cmpt_ctrl_marker             = 0;
assign c2h_cmpt_ctrl_user_trig          = 1'b1;
assign c2h_cmpt_ctrl_no_wrb_marker      = 0;        // 1'b0 : CMPT packets are sent to CMPT ring
                                                    // 1'b1 : CMPT packets are not sent to CMPT ring
                                                    
assign c2h_cmpt_ctrl_col_idx            = 0;        // Unused
assign c2h_cmpt_ctrl_err_idx            = 0;        // Unused
assign c2h_cmpt_ctrl_port_id            = 0;        // Unused

assign pkt_cntr_next = eop ? pkt_cntr_ff + 1'b1 : pkt_cntr_ff;

always_ff @(posedge clk) begin
    if(!rst_n) begin
        pkt_cntr_ff <= 16'b1; // Starts with 1
    end
    else begin
        pkt_cntr_ff <= pkt_cntr_next;
    end
end

// CMPT FSM
always_ff @(posedge clk) begin
    if(!rst_n) begin
        cmpt_state_ff <= CMPT_START;
        c2h_cmpt_tvalid <= 0;
    end
    else begin
        case(cmpt_state_ff)
            CMPT_START: begin
                if(sop) begin
                    cmpt_state_ff <= CMPT_DONE;
                    c2h_cmpt_tvalid <= 1'b1;
                end
            end
            CMPT_DONE: begin
                if(cmpt_handshake) begin
                    cmpt_state_ff <= CMPT_START;
                    c2h_cmpt_tvalid <= 0;
                end
            end
            default: begin
                cmpt_state_ff <= CMPT_START;
            end
        endcase
    end
end

// CMPT data odd parity
generate
    begin
        for (genvar i = 0; i < (512 / 32); i++) begin
            assign c2h_cmpt_dpar[i] = !(^c2h_cmpt_tdata[(32 * (i + 1) - 1):(32 * i)]);
        end
    end
endgenerate

endmodule
