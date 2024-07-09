`timescale 1ns/1ns

`define VA_WORD_LEN 256

`define TEST_IN_BUS_WORDS 4
`define TEST_OUT_BUS_WORDS 4
`define TEST_BUFF_SIZE 512

`define TEST_BEATS 10
`define TEST_DEV_ID 0

`define TEST_DEBUG_PRINT

module tb;

    localparam IN_BUS_LEN = `VA_WORD_LEN * `TEST_IN_BUS_WORDS;
    localparam IN_BUS_BYTES = IN_BUS_LEN / 8;

    localparam OUT_BUS_LEN = `VA_WORD_LEN * `TEST_OUT_BUS_WORDS;
    localparam OUT_BUS_BYTES = OUT_BUS_LEN / 8;

    bit [IN_BUS_LEN] in_bus;
    bit [OUT_BUS_LEN] out_bus;

    import "DPI-C" function void dpi_perf_start();
    import "DPI-C" function void dpi_perf_print_freq(input longint unsigned beats);

    import "DPI-C" function void dpi_va_init(input string args[]);
    import "DPI-C" function void dpi_va_deinit();

    import "DPI-C" function int dpi_va_dev_open(input shortint unsigned dev_id, input int unsigned ring_depth, input int unsigned buff_size);
    import "DPI-C" function int dpi_va_dev_remove(input shortint unsigned dev_id);
    import "DPI-C" function int dpi_va_dev_close(input shortint unsigned dev_id);

    import "DPI-C" function void dpi_va_dev_step(
        input shortint unsigned dev_id,
        input bit [IN_BUS_LEN-1:0] data_in,
        input int unsigned data_in_size, 
        input int unsigned data_out_size,
        output bit [OUT_BUS_LEN-1:0] data_out
    );

    int unsigned beats;

    string args[] = {
        "test_tb",      // program name should be specified as first argument as in C main() function
        "-c", "0xf",
        "-n", "4"
    };

    process clk_proc;
    logic clk;

    task automatic do_clk(
        input int period
    );
        begin
            if(clk_proc != null)
                clk_proc.kill();

            if(period <= 0)
                $error("do_clk(): expected positive clock period");

            clk_gen(period);
        end
    endtask

    task automatic clk_gen(
        input int period
    );
        begin
            $display("Running clock with period = %d", period);

            clk = 0;
            fork
                forever #period clk = ~clk;
            join_none

            clk_proc = process::self();
        end
    endtask

    initial begin
        // Initialize EAL
        dpi_va_init(args);

        // Open PCIe QDMA accelerator device
        void'(dpi_va_dev_open(`TEST_DEV_ID, 256, `TEST_BUFF_SIZE));

        // Start clock
        beats = 0;
        clk = 0;
        do_clk(1);

        // Start perf timer
        dpi_perf_start();

        // Advance clock till end
        repeat(`TEST_BEATS) @(posedge clk) beats++;

        // Print results
        $display("\n\n*** RESULTS ***\n");
        $display("beats complete: %d", beats);

        dpi_perf_print_freq(beats);

        // Close & remove device
        void'(dpi_va_dev_remove(`TEST_DEV_ID));

        // EAL cleanup
        dpi_va_deinit();

        $finish();
    end

    initial begin
        forever begin
            @(posedge clk);

            // Randomize input value
            void'(std::randomize(in_bus));
            
            dpi_va_dev_step(
                `TEST_DEV_ID, 
                in_bus, 
                IN_BUS_BYTES, 
                OUT_BUS_BYTES, 
                out_bus
            );
            
            // Check results
            // assert(in_bus == out_bus);

            `ifdef TEST_DEBUG_PRINT
            $display("xmit [%4d bytes] %h", $bits(in_bus) / 8, in_bus);
            $display("recv [%4d bytes] %h", $bits(out_bus) / 8, out_bus);
            `endif
        end
    end

endmodule