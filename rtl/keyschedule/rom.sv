`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2026 02:55:02 PM
// Design Name: 
// Module Name: rom
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



module rom(
    input  logic       iClk,      // Clock signal
    input  logic       iReset,    // Synchronous active-high reset
    input  logic [3:0] A,        // 4-bit address input
    output logic [7:0] DOUT   // 8-bit registered output (MSB of the original 32-bit DOUT)
);

    // Synchronous memory block with reset
    always_ff @(posedge iClk or negedge iReset) begin
        if (~iReset) begin
            DOUT <= 8'h00;
        end else begin
            case (A)
                4'h0: DOUT <= 8'h01;
                4'h1: DOUT <= 8'h02;
                4'h2: DOUT <= 8'h04;
                4'h3: DOUT <= 8'h08;
                4'h4: DOUT <= 8'h10;
                4'h5: DOUT <= 8'h20;
                4'h6: DOUT <= 8'h40;
                4'h7: DOUT <= 8'h80;
                4'h8: DOUT <= 8'h1b;
                4'h9: DOUT <= 8'h36;
                default: DOUT <= 8'h00;
            endcase
        end
    end

endmodule