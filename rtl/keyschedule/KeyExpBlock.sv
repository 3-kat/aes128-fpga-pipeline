`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2026 11:15:27 AM
// Design Name: 
// Module Name: KeyExpBlock
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
 
module KeyExpBlock(
input iClk ,
input iReset ,
input [3:0] iKeyIter ,       
input [3:0] iKeyIterModNk ,
input [32*`Nb-1:0] iNkKeys ,        
input [3:0] iKeyIterDivNk ,
output [3:0] oKeyIter      ,       
output [3:0] oKeyIterModNk ,
output [32*`Nb-1:0] oNkKeys ,        
output [3:0] oKeyIterDivNk 
    );
    
    wire [3:0] keyiter[0:2],keyitermod[0:2],keyiterdiv[0:2];
    wire [32*`Nb-1:0] outkey[0:2];
 
      KeyExp1Enc keyep0(.iClk(iClk),.iReset(iReset),.iKeyIter(iKeyIter),.iKeyIterModNk(iKeyIterModNk),.iNkKeys(iNkKeys),
               .iKeyIterDivNk(iKeyIterDivNk),.oKeyIter(keyiter[0]),.oKeyIterModNk(keyitermod[0]),.oNkKeys(outkey[0]),.oKeyIterDivNk(keyiterdiv[0]));
      
      KeyExp1Enc keyep1(.iClk(iClk),.iReset(iReset),.iKeyIter(keyiter[0]),.iKeyIterModNk(keyitermod[0]),.iNkKeys(outkey[0]),
               .iKeyIterDivNk(keyiterdiv[0]),.oKeyIter(keyiter[1]),.oKeyIterModNk(keyitermod[1]),.oNkKeys(outkey[1]),.oKeyIterDivNk(keyiterdiv[1]));
       
     KeyExp1Enc keyep2(.iClk(iClk),.iReset(iReset),.iKeyIter(keyiter[1]),.iKeyIterModNk(keyitermod[1]),.iNkKeys(outkey[1]),
               .iKeyIterDivNk(keyiterdiv[1]),.oKeyIter(keyiter[2]),.oKeyIterModNk(keyitermod[2]),.oNkKeys(outkey[2]),.oKeyIterDivNk(keyiterdiv[2]));
               
     KeyExp1Enc keyep3(.iClk(iClk),.iReset(iReset),.iKeyIter(keyiter[2]),.iKeyIterModNk(keyitermod[2]),.iNkKeys(outkey[2]),
               .iKeyIterDivNk(keyiterdiv[2  ]),.oKeyIter(oKeyIter),.oKeyIterModNk(oKeyIterModNk),.oNkKeys(oNkKeys),.oKeyIterDivNk(oKeyIterDivNk));
    
endmodule
