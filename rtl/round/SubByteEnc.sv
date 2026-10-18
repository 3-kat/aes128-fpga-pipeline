`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/19/2026 04:19:58 PM
// Design Name: 
// Module Name: SubByteEnc
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


module SubBytesEnc(
input iClk,
input iReset,
input [127:0] iBlockIn,
output [127:0] oBlockOut,
input iReady,
output oValid    
    );
 

 reg valid;
 
 genvar i ;
 
 generate
     for(i=0;i<8;i++)begin:romdp
       rom8x256dp rom(.clka(iClk),.clkb(iClk),.addra(iBlockIn[127-(16*i) -:8]),.addrb(iBlockIn[119-(16*i) -:8]),.dinb(8'h00),.web(1'b0),.douta(oBlockOut[127-(16*i) -:8]),.doutb(oBlockOut[119-(16*i) -:8]));
     end
 endgenerate
 
 
 always@(posedge iClk or negedge iReset)begin
   if(~iReset)begin
      valid<=0;
   end
   else begin
      valid<=iReady;
   end
 end
 
 assign oValid = valid;
 
endmodule


