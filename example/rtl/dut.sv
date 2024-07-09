module dut #(
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
