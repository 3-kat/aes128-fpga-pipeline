`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/20/2026 12:29:28 PM
// Design Name: 
// Module Name: ShiftRowsEnc
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


module ShiftRowsEnc(
input [127:0]iBlockIn,
output [127:0]oBlockOut,
input iReady,
output oValid
    );

wire [7:0] s[4][4],sn[4][4];
genvar i,j ;

generate
  for(i=0;i<4;i++)begin
     for(j=0;j<4;j++)begin
        assign s[i][j]=iBlockIn[127-32*j-8*i:120-32*j-8*i];
        assign oBlockOut[127-32*j-8*i:120-32*j-8*i]=sn[i][j];
     end
  end 
endgenerate

assign {sn[0][0],sn[0][1],sn[0][2],sn[0][3]}={s[0][0],s[0][1],s[0][2],s[0][3]};
assign {sn[1][0],sn[1][1],sn[1][2],sn[1][3]}={s[1][1],s[1][2],s[1][3],s[1][0]};
assign {sn[2][0],sn[2][1],sn[2][2],sn[2][3]}={s[2][2],s[2][3],s[2][0],s[2][1]};
assign {sn[3][0],sn[3][1],sn[3][2],sn[3][3]}={s[3][3],s[3][0],s[3][1],s[3][2]};

assign oValid = iReady;//since no cobinational delay , no need for conditional valid

endmodule
