
`timescale 1ns/1ps

module block_buffer_check;

    localparam int W = 240;
    localparam int H = 240;

    localparam int BLOCKS_X = W / 8;
    localparam int BLOCKS_Y = H / 8;
    localparam int TOTAL_BLOCKS = BLOCKS_X * BLOCKS_Y;

    logic clk = 0;
    logic rst_n = 0;

    logic in_valid = 0;
    logic [7:0] y, cb, cr;

    logic block_valid;
    logic block_ready = 0;

    logic [511:0] block_y;
    logic [511:0] block_cb;
    logic [511:0] block_cr;

    logic [$clog2(BLOCKS_X)-1:0] block_col;
    logic [$clog2(BLOCKS_Y)-1:0] block_row;

    logic frame_loaded;

    integer x, yy;
    integer block_number;
    integer sample;
    integer errors = 0;
    integer checked_blocks = 0;
    integer expected_block;

    always #5 clk = ~clk;

    block_buffer_8x8 #(
        .W(W),
        .H(H)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .y(y),
        .cb(cb),
        .cr(cr),
        .block_valid(block_valid),
        .block_ready(block_ready),
        .block_y(block_y),
        .block_cb(block_cb),
        .block_cr(block_cr),
        .block_col(block_col),
        .block_row(block_row),
        .frame_loaded(frame_loaded)
    );

    // Deterministic synthetic image generator.
    function automatic [7:0] expected_y(input integer px, py);
        expected_y = (px + py) & 255;
    endfunction

    function automatic [7:0] expected_cb(input integer px, py);
        expected_cb = (2*px + py) & 255;
    endfunction

    function automatic [7:0] expected_cr(input integer px, py);
        expected_cr = (px + 3*py) & 255;
    endfunction

    // Send the complete image in raster order.
    initial begin
        y = 0;
        cb = 0;
        cr = 0;

        repeat (3) @(negedge clk);
        rst_n = 1;

        for (yy = 0; yy < H; yy = yy + 1) begin
            for (x = 0; x < W; x = x + 1) begin
                @(negedge clk);
                in_valid = 1;
                y  = expected_y(x, yy);
                cb = expected_cb(x, yy);
                cr = expected_cr(x, yy);
            end
        end

        @(negedge clk);
        in_valid = 0;

        wait (frame_loaded);
        $display("Synthetic frame loaded.");

        // Inspect first, middle and last blocks.
        // The consumer accepts only the selected blocks.
        for (expected_block = 0;
             expected_block < TOTAL_BLOCKS;
             expected_block = expected_block + 1) begin

            if (expected_block == 0 ||
                expected_block == TOTAL_BLOCKS/2 ||
                expected_block == TOTAL_BLOCKS-1) begin

                wait (block_valid === 1'b1);
                #1;

                if (block_row !== expected_block / BLOCKS_X ||
                    block_col !== expected_block % BLOCKS_X) begin

                    $display(
                        "BLOCK COORDINATE ERROR: index=%0d row=%0d col=%0d",
                        expected_block, block_row, block_col
                    );
                    errors++;
                end

                for (sample = 0; sample < 64; sample = sample + 1) begin
                    x = (expected_block % BLOCKS_X) * 8 + (sample % 8);
                    yy = (expected_block / BLOCKS_X) * 8 + (sample / 8);

                    if (block_y[sample*8 +: 8] !== expected_y(x, yy)) begin
                        if (errors < 10)
                            $display(
                                "Y ERROR block=%0d sample=%0d got=%02x expected=%02x",
                                expected_block, sample,
                                block_y[sample*8 +: 8], expected_y(x, yy)
                            );
                        errors++;
                    end

                    if (block_cb[sample*8 +: 8] !== expected_cb(x, yy)) begin
                        if (errors < 10)
                            $display(
                                "Cb ERROR block=%0d sample=%0d got=%02x expected=%02x",
                                expected_block, sample,
                                block_cb[sample*8 +: 8], expected_cb(x, yy)
                            );
                        errors++;
                    end

                    if (block_cr[sample*8 +: 8] !== expected_cr(x, yy)) begin
                        if (errors < 10)
                            $display(
                                "Cr ERROR block=%0d sample=%0d got=%02x expected=%02x",
                                expected_block, sample,
                                block_cr[sample*8 +: 8], expected_cr(x, yy)
                            );
                        errors++;
                    end
                end

                checked_blocks++;
                $display(
                    "Checked block %0d: row=%0d col=%0d",
                    expected_block, block_row, block_col
                );

                // Accept this block and advance to the next one.
                @(negedge clk);
                block_ready = 1;

                @(negedge clk);
                block_ready = 0;
            end else begin
                // Advance past unselected blocks without checking them.
                wait (block_valid === 1'b1);
                @(negedge clk);
                block_ready = 1;
                @(negedge clk);
                block_ready = 0;
            end
        end

        $display("--------------------------------");
        $display("Blocks content-checked: %0d / 3", checked_blocks);
        $display("Errors: %0d", errors);

        if (checked_blocks == 3 && errors == 0)
            $display("BLOCK CONTENT TEST PASS");
        else
            $fatal(1, "BLOCK CONTENT TEST FAIL");

        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "TIMEOUT: block buffer test did not complete");
    end

endmodule
