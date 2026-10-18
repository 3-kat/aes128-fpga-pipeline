`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/01/2026 01:31:32 AM
// Design Name: 
// Module Name: InputRegsEnc
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
`define Nb 4

module InputRegsEnc(
input iClk,
input iReset,
input [32*`Nb-1:0] iKey,
input iNewKey,
input [127:0] iPlaintext,
output oKeysValid,
input iReady,
output [32*`Nb-1:0] oKey,
output [127:0] oPlaintext,
output oReady
    );
    
    reg [32*`Nb-1:0] keyout;
    reg [32*`Nb-1:0] plainout;
    reg readyout;
    reg keyvalid;
    
    always@(posedge iClk or negedge iReset)begin
      if(~iReset)begin
       keyout<=0;
       plainout<=0;
       readyout<=0;
       keyvalid<=0;
      end
      else begin
       plainout<=iPlaintext;
       readyout<=iReady;
       if(iNewKey)begin
           keyout<=iKey;
           keyvalid<=1'b1;
       end
      end
    end
    
    assign oKey = keyout;
    assign oPlaintext = plainout;
    assign oReady = readyout;
    assign oKeysValid = keyvalid;
    
    
    
endmodule
