`timescale 1ns/1ps

module rgb_to_ycbcr (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       in_valid,
    input  logic [7:0] r, g, b,
    output logic       out_valid,
    output logic [7:0] y, cb, cr
);
    logic signed [17:0] y_acc, cb_acc, cr_acc;
    logic               v1;
 
    always_ff @(posedge clk) begin
        y_acc  <=   77 * $signed({1'b0, r}) + 150 * $signed({1'b0, g}) +  29 * $signed({1'b0, b});
        cb_acc <=  -43 * $signed({1'b0, r}) -  85 * $signed({1'b0, g}) + 128 * $signed({1'b0, b});
        cr_acc <=  128 * $signed({1'b0, r}) - 107 * $signed({1'b0, g}) -  21 * $signed({1'b0, b});
    end
 
    always_ff @(posedge clk) begin
        y  <= y_acc[15:8];
        cb <= 8'((cb_acc >>> 8) + 18'sd128);
        cr <= 8'((cr_acc >>> 8) + 18'sd128);
    end
 
    // Valid flag travels with the data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1        <= 1'b0;
            out_valid <= 1'b0;
        end else begin
            v1        <= in_valid;
            out_valid <= v1;
        end
    end
endmodule