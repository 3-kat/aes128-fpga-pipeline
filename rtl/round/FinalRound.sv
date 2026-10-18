`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2026 11:38:07 AM
// Design Name: 
// Module Name: FinalRound
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
module FinalRound(
  output [32*`Nb-1:0]   oBlockOut,
  output                oValid,
  input                 iClk,
  input                 iReset,
  input  [32*`Nb-1:0]   iBlockIn,
  input  [32*`Nb-1:0]   iRoundKey,
  input                 iReady
 // input                 iRound
);

  wire [32*`Nb-1:0]  wSubOut, wShiftOut, wMixOut;
  wire               wValidSub, wValidShift, wValidMix;

  SubBytesEnc sub (
    .iClk      (iClk),
    .iReset    (iReset),
    .iBlockIn  (iBlockIn),
    .oBlockOut (wSubOut),
    .iReady    (iReady),
    .oValid    (wValidSub)
  );

  ShiftRowsEnc shift (
    .iBlockIn  (wSubOut),
    .oBlockOut (wShiftOut),
    .iReady    (wValidSub),
    .oValid    (wValidShift)
  );

  MixColumnsEnc mixcolumn (
    .iClk      (iClk),
    .iReset    (iReset),
    .iBlockIn  (wShiftOut),
    .oBlockOut (wMixOut),
    .iReady    (wValidShift),
    .oValid    (wValidMix),
    .iRound    (1'b0)
  );

  AddRoundKeyEnc addroundkey (
    .iClk      (iClk),
    .iReset    (iReset),
    .iBlockIn  (wMixOut),
    .iRoundKey (iRoundKey),
    .oBlockOut (oBlockOut),
    .iReady    (wValidMix),
    .oValid    (oValid)
  );

endmodule
