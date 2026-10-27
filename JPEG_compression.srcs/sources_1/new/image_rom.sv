
`timescale 1ns/1ps

module image_rom #(
    parameter int W = 240,
    parameter int H = 240
) (
    input  logic                       clk,
    input  logic [$clog2(W*H)-1:0]     addr,
    output logic [23:0]                pixel
);
    (* rom_style = "block" *) logic [23:0] mem [0:W*H-1];
 
    initial $readmemh("test.hex", mem);
 
    always_ff @(posedge clk)
        pixel <= mem[addr];
endmodule