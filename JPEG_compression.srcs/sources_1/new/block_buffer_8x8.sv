
`timescale 1ns/1ps

module block_buffer_8x8 #(
    parameter int W = 240,
    parameter int H = 240
) (
    input  logic clk,
    input  logic rst_n,

    // Input stream: raster order, one YCbCr pixel per valid cycle
    input  logic       in_valid,
    input  logic [7:0] y,
    input  logic [7:0] cb,
    input  logic [7:0] cr,

    // Completed block output
    output logic         block_valid,
    input  logic         block_ready,
    output logic [8*64-1:0] block_y,
    output logic [8*64-1:0] block_cb,
    output logic [8*64-1:0] block_cr,

    output logic [$clog2(W/8)-1:0] block_col,
    output logic [$clog2(H/8)-1:0] block_row,
    output logic frame_loaded
);

    localparam int N          = W * H;
    localparam int BLOCKS_X   = W / 8;
    localparam int BLOCKS_Y   = H / 8;
    localparam int TOTAL_BLOCKS = BLOCKS_X * BLOCKS_Y;

    // This initial version requires dimensions divisible by 8.
    initial begin
        if ((W % 8) != 0 || (H % 8) != 0)
            $fatal(1, "W and H must be divisible by 8");
    end

    // Full-frame component storage
    logic [7:0] y_mem  [0:N-1];
    logic [7:0] cb_mem [0:N-1];
    logic [7:0] cr_mem [0:N-1];

    // Incoming raster coordinates
    integer x_count;
    integer y_count;

    // Current output block index
    integer block_idx;

    integer row;
    integer col;
    integer pixel_addr;
    integer current_block_row;
    integer current_block_col;

    // Receive and store the complete image
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_count     <= 0;
            y_count     <= 0;
            frame_loaded <= 1'b0;
        end else begin
            if (in_valid && !frame_loaded) begin
                y_mem [y_count * W + x_count] <= y;
                cb_mem[y_count * W + x_count] <= cb;
                cr_mem[y_count * W + x_count] <= cr;

                if (x_count == W-1) begin
                    x_count <= 0;

                    if (y_count == H-1) begin
                        y_count <= 0;
                        frame_loaded <= 1'b1;
                    end else begin
                        y_count <= y_count + 1;
                    end
                end else begin
                    x_count <= x_count + 1;
                end
            end
        end
    end

    // Select an 8x8 region and expose all 64 samples
    always_comb begin
        block_valid = frame_loaded &&
                      (block_idx < TOTAL_BLOCKS);

        current_block_row = block_idx / BLOCKS_X;
        current_block_col = block_idx % BLOCKS_X;

        block_row = current_block_row;
        block_col = current_block_col;

        block_y  = '0;
        block_cb = '0;
        block_cr = '0;

        for (row = 0; row < 8; row = row + 1) begin
            for (col = 0; col < 8; col = col + 1) begin
                pixel_addr =
                    (current_block_row * 8 + row) * W
                    + current_block_col * 8 + col;

                block_y [(row*8+col)*8 +: 8] = y_mem[pixel_addr];
                block_cb[(row*8+col)*8 +: 8] = cb_mem[pixel_addr];
                block_cr[(row*8+col)*8 +: 8] = cr_mem[pixel_addr];
            end
        end
    end

    // Hold each block until the downstream stage accepts it
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            block_idx <= 0;
        end else begin
            if (block_valid && block_ready)
                block_idx <= block_idx + 1;
        end
    end

endmodule

