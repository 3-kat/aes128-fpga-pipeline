`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/20/2026 01:35:04 PM
// Design Name: 
// Module Name: tb_AddRoundKeyEnc
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
// Testbench: tb_AddRoundKeyEnc
//
// AddRoundKey is a single registered XOR — 1 cycle latency.
// oBlockOut and oValid both appear 1 posedge after iReady/iBlockIn/iRoundKey.
//
// Golden vectors verified against FIPS-197 Appendix A.
//==============================================================================

module tb_AddRoundKeyEnc;

  reg          iClk      = 0;
  reg          iReset    = 0;
  reg          iReady    = 0;
  reg  [127:0] iBlockIn  = 0;
  reg  [127:0] iRoundKey = 0;

  wire         oValid;
  wire [127:0] oBlockOut;

  always #2.5 iClk = ~iClk;   // 200 MHz

  AddRoundKeyEnc dut (
    .iClk     (iClk),
    .iReset   (iReset),
    .iBlockIn (iBlockIn),
    .iRoundKey(iRoundKey),
    .oBlockOut(oBlockOut),
    .iReady   (iReady),
    .oValid   (oValid)
  );

  //--------------------------------------------------------------------
  // Golden vectors — AddRoundKey = iBlockIn XOR iRoundKey
  //--------------------------------------------------------------------
  localparam NUM_TESTS = 5;

  reg [127:0] tv_block [0:NUM_TESTS-1];
  reg [127:0] tv_key   [0:NUM_TESTS-1];
  reg [127:0] tv_gold  [0:NUM_TESTS-1];
  reg [255:0] tv_name  [0:NUM_TESTS-1];

  initial begin
    // 1. Zero key: output = input unchanged
    tv_block[0] = 128'hDEADBEEFCAFEBABE0102030405060708;
    tv_key  [0] = 128'h00000000000000000000000000000000;
    tv_gold [0] = 128'hDEADBEEFCAFEBABE0102030405060708;
    tv_name [0] = "zero_key_identity";

    // 2. All-ones key: output = bitwise NOT of input
    tv_block[1] = 128'hDEADBEEFCAFEBABE0102030405060708;
    tv_key  [1] = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    tv_gold [1] = 128'h2152411035014541FEFDFCFBFAF9F8F7;
    tv_name [1] = "ones_key_bitwise_not";

    // 3. FIPS-197 Appendix A: initial AddRoundKey (round 0)
    //    plaintext ^ cipher_key = state going into round 1
    tv_block[2] = 128'h3243F6A8885A308D313198A2E0370734;
    tv_key  [2] = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    tv_gold [2] = 128'h193DE3BEA0F4E22B9AC68D2AE9F84808;
    tv_name [2] = "fips_round0_addroundkey";

    // 4. XOR with itself = all zeros (self-inverse property)
    tv_block[3] = 128'hCAFEBABEDEADBEEF0102030405060708;
    tv_key  [3] = 128'hCAFEBABEDEADBEEF0102030405060708;
    tv_gold [3] = 128'h00000000000000000000000000000000;
    tv_name [3] = "xor_with_self_zeros";

    // 5. Incrementing block, arbitrary key
    tv_block[4] = 128'h000102030405060708090A0B0C0D0E0F;
    tv_key  [4] = 128'hABCDEF0123456789AABBCCDDEEFF0011;
    tv_gold [4] = 128'hABCCED022740618EA2B2C6D6E2F20E1E;
    tv_name [4] = "incrementing_block";
  end

  //--------------------------------------------------------------------
  // Scoreboard
  //--------------------------------------------------------------------
  integer pass_count = 0;
  integer fail_count = 0;

  //--------------------------------------------------------------------
  // Task: drive inputs for 1 cycle, capture output on the next posedge
  //--------------------------------------------------------------------
  task drive_and_check;
    input [127:0] blk;
    input [127:0] key;
    input [127:0] golden;
    input [255:0] tname;
    begin
      // Apply on negedge — next posedge samples and registers
      @(negedge iClk);
      iBlockIn  <= blk;
      iRoundKey <= key;
      iReady    <= 1;

      // 1-cycle hold
      @(negedge iClk);
      iReady <= 0;

      // Output appears on the posedge between the two negedges above
      // Sample it right after that posedge settles
      @(posedge iClk); #1;

      if (oValid !== 1'b1) begin
        $display("FAIL [%0s]: oValid not asserted", tname);
        fail_count = fail_count + 1;
      end else if (oBlockOut === golden) begin
        $display("PASS [%0s]", tname);
        $display("       out = 128'h%032H", oBlockOut);
        pass_count = pass_count + 1;
      end else begin
        $display("FAIL [%0s]:", tname);
        $display("       block    = 128'h%032H", blk);
        $display("       key      = 128'h%032H", key);
        $display("       expected = 128'h%032H", golden);
        $display("       got      = 128'h%032H", oBlockOut);
        fail_count = fail_count + 1;
      end

      // Let pipeline drain
      @(posedge iClk);
    end
  endtask

  //--------------------------------------------------------------------
  // Main sequence
  //--------------------------------------------------------------------
  integer t;

  initial begin
    $dumpfile("tb_AddRoundKeyEnc.vcd");
    $dumpvars(0, tb_AddRoundKeyEnc);

    $display("================================================");
    $display("  AddRoundKeyEnc Testbench  (200 MHz, 1-stage) ");
    $display("================================================");

    // Reset
    iReset = 0;
    repeat(3) @(posedge iClk);
    iReset = 1;
    repeat(2) @(posedge iClk);

    // Reset check
    $display("\n-- Reset check --");
    if (oValid !== 1'b0 || oBlockOut !== 128'h0) begin
      $display("FAIL: outputs not cleared after reset");
      fail_count = fail_count + 1;
    end else begin
      $display("PASS: oValid=0, oBlockOut=0 after reset");
      pass_count = pass_count + 1;
    end

    // Functional vectors
    $display("\n-- Functional vectors --");
    for (t = 0; t < NUM_TESTS; t = t + 1)
      drive_and_check(tv_block[t], tv_key[t], tv_gold[t], tv_name[t]);

    // Summary
    $display("\n================================================");
    $display("  Results: %0d PASSED  %0d FAILED", pass_count, fail_count);
    $display("================================================");
    if (fail_count == 0)
      $display("  ALL TESTS PASSED");
    else
      $display("  SOME TESTS FAILED");

    $finish;
  end

  initial begin #20000; $display("WATCHDOG TIMEOUT"); $finish; end

  // Monitor
  always @(posedge iClk)
    if (oValid)
      $display("  [t=%0t ns] oValid=1  out=128'h%032H", $time/1000, oBlockOut);

endmodule
