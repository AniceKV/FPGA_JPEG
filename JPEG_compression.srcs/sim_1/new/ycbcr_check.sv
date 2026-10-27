
`timescale 1ns/1ps

module tb;

    localparam int W = 240;
    localparam int H = 240;
    localparam int N = W * H;

    localparam int BLOCKS_X = W / 8;
    localparam int BLOCKS_Y = H / 8;
    localparam int TOTAL_BLOCKS = BLOCKS_X * BLOCKS_Y;

    logic clk = 0;
    logic rst_n = 0;
    logic start = 0;

    logic out_valid;
    logic frame_done;

    logic [7:0] y, cb, cr;

    always #5 clk = ~clk;

    image_source_top #(
        .W(W),
        .H(H)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .out_valid (out_valid),
        .y         (y),
        .cb        (cb),
        .cr        (cr),
        .frame_done(frame_done)
    );

    // Expected YCbCr values, in raster pixel order.
    logic [23:0] expected [0:N-1];

    integer fd;
    integer count = 0;
    integer errors = 0;
    integer i;

    // Count completed block handshakes.
    integer blocks_seen = 0;

    initial begin
        fd = $fopen("expected.hex", "r");

        if (fd == 0)
            $fatal(1, "ERROR: Cannot open expected.hex");

        $fclose(fd);

        for (i = 0; i < N; i = i + 1)
            expected[i] = 24'hxxxxxx;

        $readmemh("expected.hex", expected);

        for (i = 0; i < N; i = i + 1) begin
            if (^expected[i] === 1'bx)
                $fatal(1,
                    "ERROR: Missing or invalid reference data at pixel %0d",
                    i);
        end

        $display("Reference file loaded: expected.hex");
        $display("Reference pixels: %0d", N);
    end

    // Verify each valid pixel.
    always @(posedge clk) begin
        if (rst_n && out_valid && count < N) begin
            if ({y, cb, cr} !== expected[count]) begin
                errors++;

                if (errors <= 10)
                    $display(
                        "MISMATCH pixel %0d: got %02x%02x%02x expected %06x",
                        count, y, cb, cr, expected[count]
                    );
            end

            count++;
        end
    end

    // Count block transfers from the internal buffer.
    // A transfer occurs when block_valid and block_ready are both high.
    always @(posedge clk) begin
        if (!rst_n) begin
            blocks_seen <= 0;
        end else if (
            dut.u_block_buffer.block_valid &&
            dut.u_block_buffer.block_ready
        ) begin
            blocks_seen <= blocks_seen + 1;
        end
    end

    initial begin
        // Reset, then start the image stream.
        #20;
        rst_n = 1;

        #20;
        start = 1;

        #10;
        start = 0;

        // Wait for the pixel stream to finish.
        wait (frame_done === 1'b1);

        // Allow the final pixel to be counted.
        repeat (5) @(negedge clk);

        $display("--------------------------------");
        $display("PIXEL VERIFICATION");
        $display("Pixels checked : %0d / %0d", count, N);
        $display("Pixel errors   : %0d", errors);

        if (count != N || errors != 0)
            $fatal(1, "Pixel verification FAILED");

        $display("Pixel verification PASS");

        // Wait until every 8x8 block has been accepted.
        // The buffer has 30 x 30 = 900 blocks for a 240x240 image.
        wait (blocks_seen == TOTAL_BLOCKS);

        // Allow registered updates to settle.
        repeat (2) @(negedge clk);

        $display("--------------------------------");
        $display("BLOCK BUFFER VERIFICATION");
        $display("Blocks accepted: %0d / %0d",
                 blocks_seen, TOTAL_BLOCKS);

        if (blocks_seen != TOTAL_BLOCKS)
            $fatal(1, "Block buffer verification FAILED");

        $display("Block transfer count PASS");
        $display("--------------------------------");

        $finish;
    end

    // Timeout prevents a broken design from waiting forever.
    initial begin
        #2000000;
        $fatal(1, "TIMEOUT: Testbench did not complete");
    end

endmodule
