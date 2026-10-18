`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/20/2026 01:22:35 PM
// Design Name: 
// Module Name: AddRoundKeyEnc
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


module AddRoundKeyEnc(
input iClk,
input iReset,
input [127:0] iBlockIn,
input [127:0] iRoundKey,
output [127:0] oBlockOut,
input iReady,
output oValid
    );
    reg [127:0] odata;
    reg valid;
    
    always@(posedge iClk or negedge iReset)begin
       if(~iReset)begin
          valid<=0;
          odata<=0;
       end
       else begin
          valid<=iReady;
          odata<=iBlockIn^iRoundKey;
          end
    end
    
    assign oBlockOut = odata;
    assign oValid = valid;
    
endmodule
