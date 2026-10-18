`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/22/2026 11:31:29 AM
// Design Name: 
// Module Name: MixColumnsEnc
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


//We are following Little endian order where 0,0 ; 0,1 and so on bytes start from 127th bit to right.and will be arranged in a column major order


//ovalid is sent by the module whereas ready is set by the previous module 
//ovalid is sent after all the cal is complete or the task of the module is done
//the task of module is done lets say roughly after one cycle .

`define Nb 4

module MixColumnsEnc(
  input iClk,
  input iReset,
  input iReady,
  output oValid,
  input [127:0] iBlockIn,
  output [127:0] oBlockOut,
  input iRound
    );
    
    reg ovalid;
    reg validhold;
    reg [32*`Nb-1:0] blockout;
    wire [32*`Nb-1:0] w_blockout;
    
    reg [32*`Nb-1:0]bypass_r1,bypass_r2;
    reg [32*`Nb-1:0]validhold_1,validhold_2;
  genvar i;
  generate
     for(i=0;i<4;i=i+1)begin:colout
        MapColumn mc(.iClk(iClk),.iReset(iReset),.iColumnIn(iBlockIn[127-32*i:96-32*i]),.oColumnOut(w_blockout[127-32*i:96-32*i]));
     end
  
  endgenerate  
  
  always@(posedge iClk or negedge  iReset)begin
     if(~iReset)begin
       ovalid<=0;
       blockout<=0;
       validhold<=0;
       
       bypass_r1<=0;
       bypass_r2<=0;
       validhold_1<=0;
       validhold_2<=0;
      end
     else begin
       validhold<=iReady;
       ovalid<=validhold;
       blockout<=w_blockout;
       
       bypass_r1<=iBlockIn;
       bypass_r2<=bypass_r1;
       validhold_1<=iReady;
       validhold_2<=validhold_1;
     end
  end
  
  assign oBlockOut = (iRound)?blockout:bypass_r2;
  assign oValid = (iRound)?ovalid:validhold_2;
    
    
endmodule





