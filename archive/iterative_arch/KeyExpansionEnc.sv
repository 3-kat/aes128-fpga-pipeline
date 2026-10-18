`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/24/2026 11:09:58 PM
// Design Name: 
// Module Name: KeyExpansionEnc
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
  `define Nk 4 

module KeyExpansionEnc(
 input [32*`Nk-1:0]   iNkKeys,
 input  iClk,iReset,iReady,
 output [128-1:0]   oRoundKey
    );
  
  
  wire [3:0]        KeyIterIn,KeyIterOut;
  wire [3:0]        KeyIterDivNkIn,KeyIterDivNkOut;
  wire [3:0]        KeyIterModNkIn,KeyIterModNkOut;
  wire [32*`Nk-1:0] NkKeysOut, NkKeysIn;
  wire              wReady;
  
    assign wReady         =    iReady;
    assign KeyIterIn      =    wReady ? `Nk : KeyIterOut;
    assign oRoundKey      =    NkKeysOut[32*`Nk-1:32*`Nk-128];
    assign KeyIterModNkIn =    wReady ? 4'h0    : KeyIterModNkOut;
    assign KeyIterDivNkIn =    wReady ? 4'h1    : KeyIterDivNkOut;
    assign NkKeysIn       =    wReady ? iNkKeys : NkKeysOut;
  
  KeyExp1Enc KeyExp1(.iClk(iClk), .iReset(iReset),.iKeyIter(KeyIterIn),
   .iKeyIterModNk(KeyIterModNkIn),.iKeyIterDivNk(KeyIterDivNkIn),.iNkKeys(NkKeysIn),
   .oKeyIter(KeyIterOut), .oKeyIterModNk(KeyIterModNkOut),.oKeyIterDivNk(KeyIterDivNkOut),
   .oNkKeys(NkKeysOut)
   );
  
endmodule
