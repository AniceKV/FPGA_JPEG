
`timescale 1ns/1ps


module image_source_top #(
    parameter int W = 240,
    parameter int H = 240
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,

    output logic       out_valid,
    output logic [7:0] y, cb, cr,
    output logic       frame_done
);

    localparam int N = W * H;


    logic [$clog2(N)-1:0] addr;
    logic                 running;
    logic                 rd_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr       <= '0;
            running    <= 1'b0;
            rd_valid   <= 1'b0;
            frame_done <= 1'b0;
        end else begin
            frame_done <= 1'b0;

            // Match the synchronous ROM read latency
            rd_valid <= running;

            if (start && !running) begin
                running <= 1'b1;
                addr    <= '0;
            end else if (running) begin
                if (addr == N-1) begin
                    running    <= 1'b0;
                    frame_done <= 1'b1;
                end else begin
                    addr <= addr + 1'b1;
                end
            end
        end
    end


    // 2. Image ROM

    logic [23:0] pixel;

    image_rom #(
        .W(W),
        .H(H)
    ) u_rom (
        .clk   (clk),
        .addr  (addr),
        .pixel (pixel)
    );

    // 3. Split RGB pixel
    logic [7:0] r, g, b;

    assign r = pixel[23:16];
    assign g = pixel[15:8];
    assign b = pixel[7:0];


    // 4. RGB -> YCbCr converter

    rgb_to_ycbcr u_cc (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (rd_valid),

        .r         (r),
        .g         (g),
        .b         (b),

        .out_valid (out_valid),
        .y         (y),
        .cb        (cb),
        .cr        (cr)
    );

    // 5. 8x8 block buffer interface
    logic block_valid;
    logic block_ready;

    logic [511:0] block_y;
    logic [511:0] block_cb;
    logic [511:0] block_cr;

    logic [$clog2(W/8)-1:0] block_col;
    logic [$clog2(H/8)-1:0] block_row;

    logic frame_loaded;

    // Temporary handshake:
    // Accept every block because the DCT is not connected.
    assign block_ready = 1'b1;

    // 6. YCbCr -> 8x8 block buffer
    block_buffer_8x8 #(
        .W(W),
        .H(H)
    ) u_block_buffer (
        .clk          (clk),
        .rst_n        (rst_n),

        // Connect converter outputs to buffer inputs
        .in_valid     (out_valid),
        .y            (y),
        .cb           (cb),
        .cr            (cr),

        // Completed block interface
        .block_valid  (block_valid),
        .block_ready  (block_ready),

        .block_y      (block_y),
        .block_cb     (block_cb),
        .block_cr     (block_cr),

        .block_col    (block_col),
        .block_row    (block_row),
        .frame_loaded (frame_loaded)
    );

endmodule
