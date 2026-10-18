`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/03/2026 09:51:19 AM
// Design Name: 
// Module Name: AES_core
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


`timescale 1ns / 1ps
//==============================================================================
// Module:  AES_core
// Source:  "FPGA for Optimization" Chapter 4 — Example Design: AES
// Description:
//   Fully pipelined AES-128 encryption core.
//   One Round module per round (R1..R9) + FinalRound.
//   One KeyExpBlock per expansion step (1..9) + KeyExpInit.
//   All stages connected via iReady/oValid handshake.
//==============================================================================

`define Nb 4   // number of columns in state (fixed at 4 for AES)
`define Nk 4   // number of 32-bit words in key (4=AES-128, 6=AES-192, 8=AES-256)
`define Nr 10  // number of rounds (10 for AES-128)

module AES_core (
    output [32*`Nb-1:0] oCiphertext,   // output ciphertext
    output              oValid,         // data at output is valid
    input               iClk,
    input               iReset,
    input  [32*`Nb-1:0] iPlaintext,    // input data to be encrypted
    input  [32*`Nk-1:0] iKey,          // input cipher key
    input               iReady         // valid data to encrypt
);

    //--------------------------------------------------------------------------
    // Round key wires (128-bit each)
    //--------------------------------------------------------------------------
    wire [32*`Nb-1:0] wRoundKey1,  wRoundKey2,  wRoundKey3,  wRoundKey4,
                      wRoundKey5,  wRoundKey6,  wRoundKey7,  wRoundKey8,
                      wRoundKey9,  wRoundKeyFinal, wRoundKeyInit;

    //--------------------------------------------------------------------------
    // Block data wires between pipeline stages
    //--------------------------------------------------------------------------
    wire [32*`Nb-1:0] wBlockOut1,  wBlockOut2,  wBlockOut3,  wBlockOut4,
                      wBlockOut5,  wBlockOut6,  wBlockOut7,  wBlockOut8,
                      wBlockOut9,  wBlockOutInit;

    //--------------------------------------------------------------------------
    // Key schedule sliding window wires (Nk words wide)
    //--------------------------------------------------------------------------
    wire [32*`Nk-1:0] wNkKeys1,  wNkKeys2,  wNkKeys3,  wNkKeys4,
                      wNkKeys5,  wNkKeys6,  wNkKeys7,  wNkKeys8,
                      wNkKeys9,  wNkKeysFinal, wNkKeysInit;

    //--------------------------------------------------------------------------
    // Key expansion iteration counter wires
    //--------------------------------------------------------------------------
    wire [3:0] wKeyIter1,  wKeyIter2,  wKeyIter3,  wKeyIter4,
               wKeyIter5,  wKeyIter6,  wKeyIter7,  wKeyIter8,
               wKeyIter9,  wKeyIterFinal, wKeyIterInit;

    wire [3:0] wKeyIterModNk1,  wKeyIterModNk2,  wKeyIterModNk3,  wKeyIterModNk4,
               wKeyIterModNk5,  wKeyIterModNk6,  wKeyIterModNk7,  wKeyIterModNk8,
               wKeyIterModNk9,  wKeyIterModNkFinal, wKeyIterModNkInit;

    wire [3:0] wKeyIterDivNk1,  wKeyIterDivNk2,  wKeyIterDivNk3,  wKeyIterDivNk4,
               wKeyIterDivNk5,  wKeyIterDivNk6,  wKeyIterDivNk7,  wKeyIterDivNk8,
               wKeyIterDivNk9,  wKeyIterDivNkFinal, wKeyIterDivNkInit;

    //--------------------------------------------------------------------------
    // Valid/ready handshake wires between pipeline stages
    //--------------------------------------------------------------------------
    wire wValid1, wValid2, wValid3, wValid4,
         wValid5, wValid6, wValid7, wValid8,
         wValid9, wValidFinal, wValidInit;

    //--------------------------------------------------------------------------
    // Registered inputs
    //--------------------------------------------------------------------------
    wire [32*`Nk-1:0] wKeyReg;
    wire               wReadyReg;
    wire [127:0]       wPlaintextReg;
    wire okeysvalid;
    //--------------------------------------------------------------------------
    // Key slice assignments
    //--------------------------------------------------------------------------

    // Initial round key: top 128 bits of the registered key
    assign wRoundKeyInit = wKeyReg[32*`Nk-1 : 32*`Nk-128];

    // Round keys: bottom 128 bits of each sliding key window output
    assign wRoundKey1 = wNkKeysInit[32*`Nb-1:0];
    assign wRoundKey2 = wNkKeys1   [32*`Nb-1:0];
    assign wRoundKey3 = wNkKeys2   [32*`Nb-1:0];
    assign wRoundKey4 = wNkKeys3   [32*`Nb-1:0];
    assign wRoundKey5 = wNkKeys4   [32*`Nb-1:0];
    assign wRoundKey6 = wNkKeys5   [32*`Nb-1:0];
    assign wRoundKey7 = wNkKeys6   [32*`Nb-1:0];
    assign wRoundKey8 = wNkKeys7   [32*`Nb-1:0];
    assign wRoundKey9 = wNkKeys8   [32*`Nb-1:0];

    // Final round key: bottom 128 bits of KeyExpBlock9 output
    assign wRoundKeyFinal = wNkKeys9[32*`Nb-1:0];

    //--------------------------------------------------------------------------
    // Input register stage
    //--------------------------------------------------------------------------
    InputRegsEnc InputRegsEnc (
        .iClk      (iClk),
        .iReset    (iReset),
        .iNewKey    (1'b1),
        .iKey      (iKey),
        .iPlaintext(iPlaintext),
        .iReady    (iReady),
        .oKey      (wKeyReg),
        .oPlaintext(wPlaintextReg),
        .oReady    (wReadyReg),
        .oKeysValid (okeysvalid)
    );

    //--------------------------------------------------------------------------
    // Initial key expansion (handles first expansion word, sets up counters)
    //--------------------------------------------------------------------------
    KeyExpInit KeyExpInit (
        .iClk          (iClk),
        .iReset        (iReset),
        .iNkKeys       (wKeyReg),
        .oKeyIter      (wKeyIterInit),
        .oKeyIterModNk (wKeyIterModNkInit),
        .oNkKeys       (wNkKeysInit),
        .oKeyIterDivNk (wKeyIterDivNkInit)
    );

    //--------------------------------------------------------------------------
    // Initial AddRoundKey (key whitening before round 1)
    //--------------------------------------------------------------------------
    AddRoundKeyEnc InitialKey (
        .iClk     (iClk),
        .iReset   (iReset),
        .iBlockIn (wPlaintextReg),
        .iRoundKey(wRoundKeyInit),
        .oBlockOut(wBlockOutInit),
        .iReady   (wReadyReg),
        .oValid   (wValidInit)
    );

    //--------------------------------------------------------------------------
    // Key expansion pipeline (9 stages for AES-128, one word per stage)
    //--------------------------------------------------------------------------
    KeyExpBlock KeyExpBlock1 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIterInit),    .iKeyIterModNk (wKeyIterModNkInit),
        .iNkKeys       (wNkKeysInit),     .iKeyIterDivNk (wKeyIterDivNkInit),
        .oKeyIter      (wKeyIter1),       .oKeyIterModNk (wKeyIterModNk1),
        .oNkKeys       (wNkKeys1),        .oKeyIterDivNk (wKeyIterDivNk1)
    );

    KeyExpBlock KeyExpBlock2 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIter1),       .iKeyIterModNk (wKeyIterModNk1),
        .iNkKeys       (wNkKeys1),        .iKeyIterDivNk (wKeyIterDivNk1),
        .oKeyIter      (wKeyIter2),       .oKeyIterModNk (wKeyIterModNk2),
        .oNkKeys       (wNkKeys2),        .oKeyIterDivNk (wKeyIterDivNk2)
    );

    KeyExpBlock KeyExpBlock3 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIter2),       .iKeyIterModNk (wKeyIterModNk2),
        .iNkKeys       (wNkKeys2),        .iKeyIterDivNk (wKeyIterDivNk2),
        .oKeyIter      (wKeyIter3),       .oKeyIterModNk (wKeyIterModNk3),
        .oNkKeys       (wNkKeys3),        .oKeyIterDivNk (wKeyIterDivNk3)
    );

    KeyExpBlock KeyExpBlock4 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIter3),       .iKeyIterModNk (wKeyIterModNk3),
        .iNkKeys       (wNkKeys3),        .iKeyIterDivNk (wKeyIterDivNk3),
        .oKeyIter      (wKeyIter4),       .oKeyIterModNk (wKeyIterModNk4),
        .oNkKeys       (wNkKeys4),        .oKeyIterDivNk (wKeyIterDivNk4)
    );

    KeyExpBlock KeyExpBlock5 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIter4),       .iKeyIterModNk (wKeyIterModNk4),
        .iNkKeys       (wNkKeys4),        .iKeyIterDivNk (wKeyIterDivNk4),
        .oKeyIter      (wKeyIter5),       .oKeyIterModNk (wKeyIterModNk5),
        .oNkKeys       (wNkKeys5),        .oKeyIterDivNk (wKeyIterDivNk5)
    );

    KeyExpBlock KeyExpBlock6 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIter5),       .iKeyIterModNk (wKeyIterModNk5),
        .iNkKeys       (wNkKeys5),        .iKeyIterDivNk (wKeyIterDivNk5),
        .oKeyIter      (wKeyIter6),       .oKeyIterModNk (wKeyIterModNk6),
        .oNkKeys       (wNkKeys6),        .oKeyIterDivNk (wKeyIterDivNk6)
    );

    KeyExpBlock KeyExpBlock7 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIter6),       .iKeyIterModNk (wKeyIterModNk6),
        .iNkKeys       (wNkKeys6),        .iKeyIterDivNk (wKeyIterDivNk6),
        .oKeyIter      (wKeyIter7),       .oKeyIterModNk (wKeyIterModNk7),
        .oNkKeys       (wNkKeys7),        .oKeyIterDivNk (wKeyIterDivNk7)
    );

    KeyExpBlock KeyExpBlock8 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIter7),       .iKeyIterModNk (wKeyIterModNk7),
        .iNkKeys       (wNkKeys7),        .iKeyIterDivNk (wKeyIterDivNk7),
        .oKeyIter      (wKeyIter8),       .oKeyIterModNk (wKeyIterModNk8),
        .oNkKeys       (wNkKeys8),        .oKeyIterDivNk (wKeyIterDivNk8)
    );

    KeyExpBlock KeyExpBlock9 (
        .iClk          (iClk),           .iReset        (iReset),
        .iKeyIter      (wKeyIter8),       .iKeyIterModNk (wKeyIterModNk8),
        .iNkKeys       (wNkKeys8),        .iKeyIterDivNk (wKeyIterDivNk8),
        .oKeyIter      (wKeyIter9),       .oKeyIterModNk (wKeyIterModNk9),
        .oNkKeys       (wNkKeys9),        .oKeyIterDivNk (wKeyIterDivNk9)
    );

    //--------------------------------------------------------------------------
    // Round transformation pipeline (rounds 1..9, each = SubBytes +
    // ShiftRows + MixColumns + AddRoundKey)
    //--------------------------------------------------------------------------
    Round R1 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOutInit),.iRoundKey(wRoundKey1),
        .oBlockOut(wBlockOut1),  .iReady   (wValidInit),
        .oValid   (wValid1)
    );

    Round R2 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOut1),  .iRoundKey(wRoundKey2),
        .oBlockOut(wBlockOut2),  .iReady   (wValid1),
        .oValid   (wValid2)
    );

    Round R3 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOut2),  .iRoundKey(wRoundKey3),
        .oBlockOut(wBlockOut3),  .iReady   (wValid2),
        .oValid   (wValid3)
    );

    Round R4 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOut3),  .iRoundKey(wRoundKey4),
        .oBlockOut(wBlockOut4),  .iReady   (wValid3),
        .oValid   (wValid4)
    );

    Round R5 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOut4),  .iRoundKey(wRoundKey5),
        .oBlockOut(wBlockOut5),  .iReady   (wValid4),
        .oValid   (wValid5)
    );

    Round R6 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOut5),  .iRoundKey(wRoundKey6),
        .oBlockOut(wBlockOut6),  .iReady   (wValid5),
        .oValid   (wValid6)
    );

    Round R7 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOut6),  .iRoundKey(wRoundKey7),
        .oBlockOut(wBlockOut7),  .iReady   (wValid6),
        .oValid   (wValid7)
    );

    Round R8 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOut7),  .iRoundKey(wRoundKey8),
        .oBlockOut(wBlockOut8),  .iReady   (wValid7),
        .oValid   (wValid8)
    );

    Round R9 (
        .iClk     (iClk),        .iReset   (iReset),
        .iBlockIn (wBlockOut8),  .iRoundKey(wRoundKey9),
        .oBlockOut(wBlockOut9),  .iReady   (wValid8),
        .oValid   (wValid9)
    );

    //--------------------------------------------------------------------------
    // Final round (SubBytes + ShiftRows + AddRoundKey, no MixColumns)
    //--------------------------------------------------------------------------
    FinalRound FinalRound (
        .iClk     (iClk),       .iReset   (iReset),
        .iBlockIn (wBlockOut9), .iRoundKey(wRoundKeyFinal),
        .oBlockOut(oCiphertext),.iReady   (wValid9),
        .oValid   (oValid)
    );

endmodule