`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/22/2026 04:40:33 PM
// Design Name: 
// Module Name: KeyExp1Enc
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
  
module KeyExp1Enc(
// updated values to be passed to next iteration
output reg [3:0]            oKeyIter, oKeyIterModNk,
                        oKeyIterDivNk,
output wire [32*`Nk-1:0]     oNkKeys,
input                   iClk, iReset,
// represents total # of iterations and value mod Nk
input [3:0]             iKeyIter, iKeyIterModNk,
                        iKeyIterDivNk,
// The last Nk keys generated in key expansion
input [32*`Nk-1:0]      iNkKeys
);
// updated values to be passed to next iteration





reg [32*`Nk-1:0]        OldKeys;
wire [31:0]              InterKey; // intermediate key value
wire [31:0]             PrevKey, RotWord, SubWord,
                        NewKeyWord;

wire [31:0]             Rcon;
wire [7:0]              Rcon_byte;


assign PrevKey        = iNkKeys[31:0]; // last word in key array

// 1 byte cyclic permutation
assign RotWord        = {PrevKey[23:0], PrevKey[31:24]};



// calculate Rcon over GF(2^8)
//assign Rcon           = iKeyIterDivNk == 8'h1 ? 32'h01000000:
//                        iKeyIterDivNk == 8'h2 ? 32'h02000000:
//                        iKeyIterDivNk == 8'h3 ? 32'h04000000:
//                        iKeyIterDivNk == 8'h4 ? 32'h08000000:
//                        iKeyIterDivNk == 8'h5 ? 32'h10000000:
//                        iKeyIterDivNk == 8'h6 ? 32'h20000000:
//                        iKeyIterDivNk == 8'h7 ? 32'h40000000:
//                        iKeyIterDivNk == 8'h8 ? 32'h80000000:
//                        iKeyIterDivNk == 8'h9 ? 32'h1b000000:
//                        32'h36000000;

//to add one extra pipeline stage we make rcon as a rom

wire [3:0] rcon_addr = (iKeyIterDivNk > 0) ? (iKeyIterDivNk - 4'd1) : 4'h0;

   rom Rcon1(.iClk(iClk),.iReset(iReset),.A(rcon_addr), .DOUT(Rcon_byte[7:0]));//to make sure the under flow doesnt happen
   //we write iKeyIterDivNk > 0 ? iKeyIterDivNk-1 : 4'h0 even though divnk>=1

 assign Rcon = {Rcon_byte,{24{1'b0}}};
 

//SboxEnc SboxEnc0(.iPreMap(RotWord[31:24]),
//.oPostMap(SubWord[31:24]));
//SboxEnc SboxEnc1(.iPreMap(RotWord[23:16]),
//.oPostMap(SubWord[23:16]));
//SboxEnc SboxEnc2(.iPreMap(RotWord[15:8]),
//.oPostMap(SubWord[15:8]));
//SboxEnc SboxEnc3(.iPreMap(RotWord[7:0]),
//.oPostMap(SubWord[7:0]));

//to add 2nd pipeline stage we use the dual port ram for sbox subtitution

rom8x256dp rom1(.clka(iClk),.clkb(iClk),.addra(RotWord[31:24]),.addrb(RotWord[23:16]),
.dinb(8'h00),.web(1'b0),.douta(SubWord[31:24]),.doutb(SubWord[23:16]));
rom8x256dp rom2(.clka(iClk),.clkb(iClk),.addra(RotWord[15:8]),.addrb(RotWord[7:0]),
.dinb(8'h00),.web(1'b0),.douta(SubWord[15:8]),.doutb(SubWord[7:0]));


`ifdef Nk8
wire [31:0] SubWordNk8;
// Substitution only when Nk = 8
//SboxEnc SboxEncNk8_0(.iPreMap(PrevKey[31:24]),
//.oPostMap(SubWordNk8[31:24]));
//SboxEnc SboxEncNk8_1(.iPreMap(PrevKey[23:16]),
//.oPostMap(SubWordNk8[23:16]));
//SboxEnc SboxEncNk8_2(.iPreMap(PrevKey[15:8]),
//.oPostMap(SubWordNk8[15:8]));
//SboxEnc SboxEncNk8_3(.iPreMap(PrevKey[7:0]),
//.oPostMap(SubWordNk8[7:0]));

rom8x256dp rom8_1(.clka(iClk),.clkb(iClk),.addra(PrevKey[31:24]),.addrb(PrevKey[23:16]),
.dinb(8'h00),.web(1'b0),.douta(SubWordNk8[31:24]),.doutb(SubWordNk8[23:16]));
rom8x256dp rom8_2(.clka(iClk),.clkb(iClk),.addra(PrevKey[15:8]),.addrb(PrevKey[7:0]),
.dinb(8'h00),.web(1'b0),.douta(SubWordNk8[15:8]),.doutb(SubWordNk8[7:0]));
`endif


always @(posedge iClk or negedge iReset)
if(!iReset) begin
    oKeyIter           <= 0;
    oKeyIterModNk      <= 0;

    oKeyIterDivNk      <= 0;
    OldKeys            <= 0;
end
else begin
    oKeyIter           <= iKeyIter + 1;
    OldKeys            <= iNkKeys;

// update "Key iteration mod Nk" for next iteration
if(iKeyIterModNk + 1 == `Nk) begin
    oKeyIterModNk      <= 0;
    oKeyIterDivNk      <= iKeyIterDivNk+1;
end
else begin
    oKeyIterModNk      <= iKeyIterModNk + 1;
    oKeyIterDivNk      <= iKeyIterDivNk;
end
//actuaklly here oKeyIterDivNk reperesent the round index 
//and okey Iter mod nk is used to check the boundary of a word , resetting it means a new word has started
//if(iKeyIterModNk == 0)
//    InterKey           <= SubWord ^ Rcon;
//`ifdef Nk8
// an option only for Nk = 8
//else if(iKeyIterModNk == 4)
//    InterKey           <= SubWordNk8;
//`endif
//else
 //   InterKey           <= PrevKey;
end
//if(iKeyIterModNk == 0)
//   InterKey           = SubWor    d ^ Rcon;
//`ifdef Nk8
//an option only for Nk = 8
//else if(iKeyIterModNk == 4)
// InterKey          = SubWordNk8;
//`endif
//else
//   InterKey           = PrevKey;
//end

//assign InterKey = (iKeyIterModNk == 0)?SubWord ^ Rcon:PrevKey;//since others are registered we try to take the registered value intead of prevkey
   assign InterKey = (iKeyIterModNk == 0)?SubWord ^ Rcon:iNkKeys[31:0];                

// new key calculated in this round
assign NewKeyWord     = OldKeys[32*`Nk-1:32*`Nk-32] ^ InterKey;//OldKeys[127:96]^intermeidate key
// calculate new key set
assign oNkKeys        = {OldKeys[32*`Nk-33:0], NewKeyWord};

endmodule
