`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/01/2026 12:31:21 AM
// Design Name: 
// Module Name: RoundsIterEnc
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
 `define Nr 10

    
module RoundsIterEnc(
input iClk,
input iReset,
input [32*`Nb-1:0] iBlockIn,
output [32*`Nb-1:0] oBlockOut,//final ciphertext
input iReady,
output oValid,
input [32*`Nb-1:0] iRoundkey
    );
  localparam TOTAL_CYCLES = 4*`Nr;        // 40 for Nr=10
  localparam LAST_ROUND_START = 4*(`Nr-1); // 36 for Nr=10
    
    
   reg [$clog2(TOTAL_CYCLES)-1:0] counter;
    
    
   wire wready;
   wire  [32*`Nb-1:0] oBlockw;
   wire  [32*`Nb-1:0] iBlockw;
   
   wire ovalidw;
   wire ireadyw;
   wire Roundflag;
   
    always @(posedge iClk or negedge iReset) begin
    if (~iReset)
      counter <= 0;
    else if (wready)              // new transaction starting -> restart count
      counter <= 0;
    else 
      counter <= counter + 1;
    // else: hold at TOTAL_CYCLES-1 until next transaction (idle)
  end
   
   assign wready = iReady; 
   assign iBlockw = wready? iBlockIn:oBlockw;
   assign ireadyw = wready? iReady:ovalidw ;
   assign oValid = (counter == TOTAL_CYCLES-1)? ovalidw: 1'b0;//whenever the iterations start, it is the vlaid of the already present valid at the end of the 
   //previous iteration
   assign Roundflag = (counter < LAST_ROUND_START);
   assign oBlockOut = oBlockw;
   
  RoundEnc RsmallE(
     .oBlockOut(oBlockw),.oValid(ovalidw),.iClk(iClk),
     .iReset(iReset),.iBlockIn(iBlockw),.iRoundKey(iRoundkey),
     .iReady(ireadyw),.iRound(Roundflag));
     
     
endmodule
