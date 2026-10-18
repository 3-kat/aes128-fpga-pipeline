`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/22/2026 11:29:18 AM
// Design Name: 
// Module Name: PolyMultx2
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

module PolyMultx2(
 input [7:0]iPolynIn,
 output [7:0]oPolyOut
);
   assign oPolyOut=(iPolynIn[7])?({iPolynIn[6:0],1'b0})^8'h1B:{iPolynIn[6:0],1'b0};
   
endmodule
