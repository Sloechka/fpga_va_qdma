`timescale 1ns / 1ps
/* --------------------------------- */
/* YOUR DUT WRAPPER IMPLEMENTATION GOES HERE */
/* --------------------------------- */

// module dut_wrapper #(
//     parameter IN_BUS_WIDTH = 256,
//     parameter OUT_BUS_WIDTH = 256
// )(
//     input logic     clk,
//     input logic     rst_n,
//     input logic     [IN_BUS_WIDTH-1:0] in,
//     output logic    [OUT_BUS_WIDTH-1:0] out
// );

// ...

module dut_test #(
    parameter SIG_WIDTH = 256
)(
    input logic     clk,
    input logic     rst_n,
    input logic     [SIG_WIDTH-1:0] in,
    output logic    [SIG_WIDTH-1:0] out
);

always_ff @(posedge clk) begin
    if(!rst_n) begin
        out <= 0;
    end
    else begin
        out <= in;
    end
end
    
endmodule
    
// endmodule
