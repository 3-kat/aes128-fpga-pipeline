`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/22/2026 11:30:41 AM
// Design Name: 
// Module Name: MapColumn
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

module MapColumn(
   input iClk,
   input iReset,
   input [31:0] iColumnIn,
   output [31:0] oColumnOut
);

 wire [7:0]spo[0:3];
 wire [7:0]sn[0:3];
 wire [7:0]s[0:3];
 reg [31:0]r_ocol;
 
   genvar i;
   
   generate
        for(i=0;i<4;i=i+1)begin:mulind
           assign s[i]=iColumnIn[31-8*i:16-8*(i-1)];
           PolyMultx2 mult(.iPolynIn(s[i]),.oPolyOut(spo[i]));
        end
        
        assign sn[0] = spo[0]^(spo[1]^s[1])^s[2]^s[3];
        assign sn[1] = s[0]^(spo[1])^(spo[2]^s[2])^s[3];
        assign sn[2] = s[0]^s[1]^(spo[2])^(spo[3]^s[3]);
        assign sn[3] = (spo[0]^s[0])^s[1]^s[2]^(spo[3]);
   endgenerate
  
  always@(posedge iClk or negedge iReset)begin
     if(~iReset)begin
        r_ocol<=32'h0000_0000;
     end
     else begin
        r_ocol <= {sn[0],sn[1],sn[2],sn[3]}; 
     end
  end   
  
  assign oColumnOut = r_ocol;    

endmodule

