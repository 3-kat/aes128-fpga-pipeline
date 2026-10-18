`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/20/2026 01:18:45 PM
// Design Name: 
// Module Name: tb_ShiftRowsEnc
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
// Testbench: tb_ShiftRowsEnc
//
// ShiftRows is purely combinational — oValid = iReady with no pipeline delay.
// Each test drives iBlockIn and iReady, waits one delta cycle for propagation,
// then immediately samples and compares oBlockOut.
//
// Golden vectors verified against FIPS-197 Appendix B column-major layout.
//==============================================================================

module tb_ShiftRowsEnc;

  reg          iReady  = 0;
  reg  [127:0] iBlockIn = 0;

  wire         oValid;
  wire [127:0] oBlockOut;

  ShiftRowsEnc dut (
    .iBlockIn (iBlockIn),
    .oBlockOut(oBlockOut),
    .iReady   (iReady),
    .oValid   (oValid)
  );

  //--------------------------------------------------------------------
  // Golden vectors — column-major layout matching your RTL
  // a[row][col] at iBlockIn[127-32*col-8*row -: 8]
  //--------------------------------------------------------------------
  localparam NUM_TESTS = 6;

  reg [127:0]  tv_in   [0:NUM_TESTS-1];
  reg [127:0]  tv_gold [0:NUM_TESTS-1];
  reg [255:0]  tv_name [0:NUM_TESTS-1];

  initial begin
    // 1. All zeros — every byte 0x00, shift of zeros is zeros
    tv_in  [0] = 128'h00000000000000000000000000000000;
    tv_gold[0] = 128'h00000000000000000000000000000000;
    tv_name[0] = "all_zeros";

    // 2. All 0xFF — uniform input, shift changes nothing
    tv_in  [1] = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    tv_gold[1] = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    tv_name[1] = "all_0xFF";

    // 3. All 0xAA — another uniform, must be unchanged
    tv_in  [2] = 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
    tv_gold[2] = 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
    tv_name[2] = "all_0xAA";

    // 4. FIPS-197 Appendix B Round 1: state after SubBytes -> ShiftRows
    //    in  col-major: [D4,27,11,AE][E0,BF,98,F1][B8,B4,5D,E5][1E,41,52,30]
    //    out col-major: [D4,BF,5D,30][E0,B4,52,AE][B8,41,11,F1][1E,27,98,E5]
    tv_in  [3] = 128'hD42711AEE0BF98F1B8B45DE51E415230;
    tv_gold[3] = 128'hD4BF5D30E0B452AEB84111F11E2798E5;
    tv_name[3] = "fips_round1_after_sbox";

    // 5. Incrementing bytes 0x00..0x0F
    //    a[row][col] = row + 4*col  (so a[0][0]=0, a[1][0]=1, a[0][1]=4...)
    //    row0 no shift: 00,04,08,0C
    //    row1 left  1:  05,09,0D,01
    //    row2 left  2:  0A,0E,02,06
    //    row3 left  3:  0F,03,07,0B
    tv_in  [4] = 128'h000102030405060708090A0B0C0D0E0F;
    tv_gold[4] = 128'h00050A0F04090E03080D02070C01060B;
    tv_name[4] = "incrementing_00_0F";

    // 6. DEADBEEF/CAFEBABE pattern
    tv_in  [5] = 128'hDEADBEEFCAFEBABE0102030405060708;
    tv_gold[5] = 128'hDEFE0308CA0207EF0106BEBE05ADBA04;
    tv_name[5] = "deadbeef_cafebabe";
  end

  //--------------------------------------------------------------------
  // Scoreboard
  //--------------------------------------------------------------------
  integer pass_count = 0;
  integer fail_count = 0;
  integer t;

  //--------------------------------------------------------------------
  // Main sequence — purely combinational so no clock needed
  //--------------------------------------------------------------------
  initial begin
    $display("================================================");
    $display("  ShiftRowsEnc Testbench (combinational)        ");
    $display("================================================");

    // Check that oValid follows iReady immediately
    $display("\n-- oValid = iReady check --");
    iReady = 0; #1;
    if (oValid !== 1'b0) begin
      $display("FAIL: oValid should be 0 when iReady=0");
      fail_count = fail_count + 1;
    end else
      $display("PASS: oValid=0 when iReady=0");

    iReady = 1; #1;
    if (oValid !== 1'b1) begin
      $display("FAIL: oValid should be 1 when iReady=1");
      fail_count = fail_count + 1;
    end else
      $display("PASS: oValid=1 when iReady=1");

    // Run all functional vectors
    $display("\n-- Functional vectors --");
    for (t = 0; t < NUM_TESTS; t = t + 1) begin
      iBlockIn = tv_in[t];
      iReady   = 1;
      #1; // one delta — combinational settle

      if (oBlockOut === tv_gold[t]) begin
        $display("PASS [%0s]", tv_name[t]);
        $display("       out = 128'h%032H", oBlockOut);
        pass_count = pass_count + 1;
      end else begin
        $display("FAIL [%0s]:", tv_name[t]);
        $display("       in       = 128'h%032H", iBlockIn);
        $display("       expected = 128'h%032H", tv_gold[t]);
        $display("       got      = 128'h%032H", oBlockOut);
        fail_count = fail_count + 1;
      end

      iReady = 0; #1;
    end

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

endmodule