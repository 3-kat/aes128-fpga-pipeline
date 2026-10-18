
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2026 11:44:23 AM
// Design Name: 
// Module Name: tb_KeyExp1Enc
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
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_KeyExp1Enc
//
// PURPOSE:
//   1. Prove KeyExp1Enc has exactly 1-cycle latency: the new word must be
//      correct exactly 1 clock after its inputs are applied - not 2.
//      (This is the thing that was ambiguous earlier in the conversation -
//      one pass was described as "2 cycles per word", the ROM-based fix was
//      supposed to bring it to 1. This test settles it empirically.)
//   2. Match FIPS-197 Appendix A.1 golden key-expansion data for
//      Key = 2b7e151628aed2a6abf7158809cf4f3c (Nk = 4), chaining
//      w0..w3 (the cipher key) through ModNk = 0,1,2,3 to reproduce
//      w4..w7 (Round Key 1: a0fafe17 88542cb1 23a33939 2a6c7605 - the
//      same Round Key 1 you've already been using in tb_RoundsIterEnc).
//
// Assumes KeyExp1Enc's port list as posted:
//   module KeyExp1Enc(
//       output reg [3:0] oKeyIter, oKeyIterModNk, oKeyIterDivNk,
//       output wire [32*`Nk-1:0] oNkKeys,
//       input iClk, iReset,
//       input [3:0] iKeyIter, iKeyIterModNk, iKeyIterDivNk,
//       input [32*`Nk-1:0] iNkKeys
//   );
// Reset is active-low (matches your "if(!iReset)" convention).
//////////////////////////////////////////////////////////////////////////////////
`ifndef NK_DEFINED_TB
`define Nk 4
`define NK_DEFINED_TB
`endif

module tb_KeyExp1Enc;

reg iClk = 0;
reg iReset = 0;
reg [3:0] iKeyIter = 0, iKeyIterModNk = 0, iKeyIterDivNk = 0;
reg [32*`Nk-1:0] iNkKeys = 0;

wire [3:0] oKeyIter, oKeyIterModNk, oKeyIterDivNk;
wire [32*`Nk-1:0] oNkKeys;

always #2.5 iClk = ~iClk;   // 200 MHz, matches the rest of the project

KeyExp1Enc dut (
    .oKeyIter     (oKeyIter),
    .oKeyIterModNk(oKeyIterModNk),
    .oKeyIterDivNk(oKeyIterDivNk),
    .oNkKeys      (oNkKeys),
    .iClk         (iClk),
    .iReset       (iReset),
    .iKeyIter     (iKeyIter),
    .iKeyIterModNk(iKeyIterModNk),
    .iKeyIterDivNk(iKeyIterDivNk),
    .iNkKeys      (iNkKeys)
);

integer pass_cnt = 0;
integer fail_cnt = 0;
task check;
    input [511:0] name;
    input cond;
    begin
        if (cond) begin
            $display("  PASS %0s", name); pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL %0s", name); fail_cnt = fail_cnt + 1;
        end
    end
endtask

// ---- FIPS-197 golden words, Key = 2b7e151628aed2a6abf7158809cf4f3c ----
localparam [31:0] W0 = 32'h2b7e1516;
localparam [31:0] W1 = 32'h28aed2a6;
localparam [31:0] W2 = 32'habf71588;
localparam [31:0] W3 = 32'h09cf4f3c;
localparam [31:0] W4 = 32'ha0fafe17;
localparam [31:0] W5 = 32'h88542cb1;
localparam [31:0] W6 = 32'h23a33939;
localparam [31:0] W7 = 32'h2a6c7605;

reg [127:0] before_word, after1_word, after2_word;

initial begin
    $dumpfile("tb_KeyExp1Enc.vcd");
    $dumpvars(0, tb_KeyExp1Enc);
    $display("=========================================");
    $display(" KeyExp1Enc - 1-cycle latency + FIPS-197 golden test");
    $display("=========================================");

    // Reset
    iReset = 0;
    repeat(3) @(posedge iClk);
    @(negedge iClk);           // release reset off-edge, no race with the DUT's
    iReset = 1;                // own posedge-triggered reset check
    repeat(2) @(posedge iClk);

    //----------------------------------------------------------------
    // T1: w0..w3 -> w4  (ModNk=0 -> SubWord^Rcon path, DivNk=1 -> Rcon[1])
    //----------------------------------------------------------------
    $display("\n[T1] w0..w3 -> w4  (ModNk=0, DivNk=1)");
    @(negedge iClk);
    iNkKeys       <= {W0, W1, W2, W3};
    iKeyIterModNk <= 4'h0;
    iKeyIterDivNk <= 4'h1;
    iKeyIter      <= 4'h3;

    before_word = oNkKeys;                 // sampled pre-edge, for reference
    @(posedge iClk); #1;
    after1_word = oNkKeys;
    check("w4 correct exactly 1 cycle after inputs applied",
          oNkKeys[31:0] === W4);
    check("upper words correctly shifted to {w1,w2,w3}",
          oNkKeys[127:32] === {W1, W2, W3});

    @(posedge iClk); #1;                   // hold inputs, re-check
    after2_word = oNkKeys;
    check("output stays stable on 2nd cycle (no hidden extra stage)",
          after2_word === after1_word);

    //----------------------------------------------------------------
    // T2: w1..w4 -> w5  (ModNk=1, straight XOR path, no SubWord/Rcon)
    //----------------------------------------------------------------
    $display("\n[T2] w1..w4 -> w5  (ModNk=1)");
    @(negedge iClk);
    iNkKeys       <= oNkKeys;              // {w1,w2,w3,w4}
    iKeyIterModNk <= 4'h1;
    @(posedge iClk); #1;
    check("w5 correct exactly 1 cycle after inputs applied",
          oNkKeys[31:0] === W5);

    //----------------------------------------------------------------
    // T3: w2..w5 -> w6  (ModNk=2)
    //----------------------------------------------------------------
    $display("\n[T3] w2..w5 -> w6  (ModNk=2)");
    @(negedge iClk);
    iNkKeys       <= oNkKeys;              // {w2,w3,w4,w5}
    iKeyIterModNk <= 4'h2;
    @(posedge iClk); #1;
    check("w6 correct exactly 1 cycle after inputs applied",
          oNkKeys[31:0] === W6);

    //----------------------------------------------------------------
    // T4: w3..w6 -> w7  (ModNk=3)
    //----------------------------------------------------------------
    $display("\n[T4] w3..w6 -> w7  (ModNk=3)");
    @(negedge iClk);
    iNkKeys       <= oNkKeys;              // {w3,w4,w5,w6}
    iKeyIterModNk <= 4'h3;
    @(posedge iClk); #1;
    check("w7 correct exactly 1 cycle after inputs applied",
          oNkKeys[31:0] === W7);
    check("Round Key 1 fully reproduced word-by-word",
          oNkKeys === {W4, W5, W6, W7});

    $display("\n=========================================");
    $display(" Results: %0d PASSED  %0d FAILED", pass_cnt, fail_cnt);
    $display("=========================================");
    if (fail_cnt == 0) $display(" ALL TESTS PASSED");
    else                $display(" SOME TESTS FAILED");
    $finish;
end

initial begin #50000; $display("WATCHDOG TIMEOUT"); $finish; end

endmodule
