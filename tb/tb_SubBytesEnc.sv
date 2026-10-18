/*`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_SubBytesEnc
//
// Purpose:
//   1. Check output correctness against FIPS-197 golden values
//   2. Measure actual latency from iReady to oValid
//
// Latency expectation:
//   BRAM registered output = 1 cycle read latency
//   + 1 cycle for valid register (valid <= iReady)
//   = 2 cycles total from posedge-that-samples-iReady to oValid high
//
// Clock: 5 ns (200 MHz)
//==============================================================================

module tb_SubBytesEnc;

  reg          iClk    = 0;
  reg          iReset  = 0;
  reg          iReady  = 0;
  reg  [127:0] iBlockIn = 0;

  wire         oValid;
  wire [127:0] oBlockOut;

  always #2.5 iClk = ~iClk;   // 200 MHz

  SubBytesEnc dut (
    .iClk    (iClk),
    .iReset  (iReset),
    .iBlockIn(iBlockIn),
    .oBlockOut(oBlockOut),
    .iReady  (iReady),
    .oValid  (oValid)
  );

  //--------------------------------------------------------------------
  // Latency measurement:
  // Record the cycle when iReady goes high and when oValid goes high.
  // Difference = pipeline latency in clock cycles.
  //--------------------------------------------------------------------
  integer ready_cycle = 0;
  integer valid_cycle = 0;
  integer cycle_count = 0;

  always @(posedge iClk) begin
    cycle_count <= cycle_count + 1;
    if (iReady && ready_cycle == 0)
      ready_cycle <= cycle_count;
    if (oValid && valid_cycle == 0)
      valid_cycle <= cycle_count;
  end

  //--------------------------------------------------------------------
  // Print every oValid pulse — main correctness check
  //--------------------------------------------------------------------
  always @(posedge iClk)
    if (oValid)
      $display("[t=%0t ns] oValid=1  oBlockOut=128'h%032H", $time/1000, oBlockOut);

  //--------------------------------------------------------------------
  // Test sequence
  //--------------------------------------------------------------------
  initial begin
    $dumpfile("tb_SubBytesEnc.vcd");
    $dumpvars(0, tb_SubBytesEnc);

    $display("================================================");
    $display("  SubBytesEnc Testbench  (200 MHz)             ");
    $display("================================================");
    $display("Golden values (FIPS-197 AES S-Box):");
    $display("  all 0x00 -> all 0x63");
    $display("  all 0xFF -> all 0x16");
    $display("  FIPS round1 in  -> FIPS round1 out");
    $display("  0x00..0x0F      -> 637C777BF26B6FC53001672BFED7AB76");
    $display("------------------------------------------------");

    // Reset
    iReset = 0;
    repeat(3) @(posedge iClk);
    iReset = 1;
    repeat(2) @(posedge iClk);

    //----------------------------------------------------------------
    // Test 1: All zeros -> expect all 0x63
    //----------------------------------------------------------------
    @(negedge iClk);
    iBlockIn <= 128'h00000000000000000000000000000000;
    iReady   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(6) @(posedge iClk);

    //----------------------------------------------------------------
    // Test 2: All 0xFF -> expect all 0x16
    //----------------------------------------------------------------
    @(negedge iClk);
    iBlockIn <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    iReady   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(6) @(posedge iClk);

    //----------------------------------------------------------------
    // Test 3: FIPS-197 Round 1 SubBytes (most important check)
    //   in:  0x193DE3BEA0F4E22B9AC68D2AE9F84808
    //   out: 0xD42711AEE0BF98F1B8B45DE51E415230
    //----------------------------------------------------------------
    @(negedge iClk);
    iBlockIn <= 128'h193DE3BEA0F4E22B9AC68D2AE9F84808;
    iReady   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(6) @(posedge iClk);

    //----------------------------------------------------------------
    // Test 4: Incrementing bytes 0x00..0x0F
    //   out: 637C777BF26B6FC53001672BFED7AB76
    //----------------------------------------------------------------
    @(negedge iClk);
    iBlockIn <= 128'h000102030405060708090A0B0C0D0E0F;
    iReady   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(6) @(posedge iClk);

    //----------------------------------------------------------------
    // Test 5: DEADBEEF pattern
    //   out: 1D95AEDF74BBF4AE7C777BF26B6FC530
    //----------------------------------------------------------------
    @(negedge iClk);
    iBlockIn <= 128'hDEADBEEFCAFEBABE0102030405060708;
    iReady   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(6) @(posedge iClk);

    //----------------------------------------------------------------
    // Latency report
    //----------------------------------------------------------------
    $display("------------------------------------------------");
    $display("Latency measurement:");
    $display("  iReady asserted at cycle: %0d", ready_cycle);
    $display("  oValid asserted at cycle: %0d", valid_cycle);
    $display("  Pipeline latency:         %0d cycles", valid_cycle - ready_cycle);
    $display("  At 200MHz that is:        %0d ns", (valid_cycle - ready_cycle)*5);
    $display("================================================");
    $display("Check oBlockOut values above against golden.");
    $display("Open tb_SubBytesEnc.vcd to inspect waveform.");

    $finish;
  end

  initial begin #10000; $display("TIMEOUT"); $finish; end

endmodule*/

`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_SubBytesEnc
// Features:
//   - Drives 5 known input vectors
//   - Captures oBlockOut on every oValid pulse (wire = Active region, no NBA issue)
//   - Compares captured value against golden immediately
//   - Reports PASS/FAIL per test and final summary
//   - Measures pipeline latency (cycles from iReady posedge to oValid posedge)
//==============================================================================

module tb_SubBytesEnc;

  reg          iClk     = 0;
  reg          iReset   = 0;
  reg          iReady   = 0;
  reg  [127:0] iBlockIn = 0;

  wire         oValid;
  wire [127:0] oBlockOut;

  always #2.5 iClk = ~iClk;   // 200 MHz

  SubBytesEnc dut (
    .iClk     (iClk),
    .iReset   (iReset),
    .iBlockIn (iBlockIn),
    .oBlockOut(oBlockOut),
    .iReady   (iReady),
    .oValid   (oValid)
  );

  //--------------------------------------------------------------------
  // Golden test vectors  (FIPS-197 AES S-Box, verified in Python)
  //--------------------------------------------------------------------
  localparam NUM_TESTS = 5;

  reg [127:0] tv_in   [0:NUM_TESTS-1];
  reg [127:0] tv_gold [0:NUM_TESTS-1];
  reg [8*32:1] tv_name [0:NUM_TESTS-1];

  initial begin
    // 1. All 0x00 -> S-Box[0x00]=0x63 for every byte
    tv_in  [0] = 128'h00000000000000000000000000000000;
    tv_gold[0] = 128'h63636363636363636363636363636363;
    tv_name[0] = "all_zeros";

    // 2. All 0xFF -> S-Box[0xFF]=0x16 for every byte
    tv_in  [1] = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    tv_gold[1] = 128'h16161616161616161616161616161616;
    tv_name[1] = "all_0xFF";

    // 3. FIPS-197 Appendix B Round 1 SubBytes
    //    in:  193DE3BEA0F4E22B9AC68D2AE9F84808
    //    out: D42711AEE0BF98F1B8B45DE51E415230
    tv_in  [2] = 128'h193DE3BEA0F4E22B9AC68D2AE9F84808;
    tv_gold[2] = 128'hD42711AEE0BF98F1B8B45DE51E415230;
    tv_name[2] = "fips_round1";

    // 4. Incrementing bytes 0x00..0x0F
    //    each byte independently looked up in S-Box
    tv_in  [3] = 128'h000102030405060708090A0B0C0D0E0F;
    tv_gold[3] = 128'h637C777BF26B6FC53001672BFED7AB76;
    tv_name[3] = "incrementing_00_0F";

    // 5. DEADBEEF/CAFEBABE pattern
    tv_in  [4] = 128'hDEADBEEFCAFEBABE0102030405060708;
    tv_gold[4] = 128'h1D95AEDF74BBF4AE7C777BF26B6FC530;
    tv_name[4] = "deadbeef_cafebabe";
  end

  //--------------------------------------------------------------------
  // Result capture
  // oValid is a wire so it is read in the Active region — no NBA lag.
  // A for-loop polls every posedge and grabs oBlockOut the instant
  // oValid is seen, same pattern proven to work in MixColumns TB.
  //--------------------------------------------------------------------
  integer pass_count = 0;
  integer fail_count = 0;

  // Latency tracking
  integer ready_cycle  = 0;
  integer valid_cycle  = 0;
  integer cycle_ctr    = 0;
  integer latency_done = 0;   // latch only the first measurement

  always @(posedge iClk) begin
    cycle_ctr = cycle_ctr + 1;
    if (iReady  && ready_cycle == 0)              ready_cycle  = cycle_ctr;
    if (oValid  && valid_cycle == 0)              valid_cycle  = cycle_ctr;
  end

  //--------------------------------------------------------------------
  // Task: drive one vector, poll for oValid, compare, print result
  //--------------------------------------------------------------------
  localparam MAX_WAIT = 12;

  task drive_and_check;
    input [127:0]  data_in;
    input [127:0]  golden;
    input [8*32:1] tname;

    integer w;
    reg     found;
    reg [127:0] got;
    begin
      found = 0;
      got   = 128'hx;

      @(negedge iClk);
      iBlockIn <= data_in;
      iReady   <= 1;

      @(negedge iClk);
      iReady <= 0;

      // Poll on every posedge; oValid is a wire so it is visible immediately
      for (w = 0; w < MAX_WAIT; w = w + 1) begin
        @(posedge iClk);
        if (oValid && !found) begin
          got   = oBlockOut;
          found = 1;
        end
      end

      // Verdict
      if (!found) begin
        $display("FAIL [%0s]: oValid never asserted within %0d cycles",
                 tname, MAX_WAIT);
        fail_count = fail_count + 1;
      end else if (got === golden) begin
        $display("PASS [%0s]", tname);
        $display("       out = 128'h%032H", got);
        pass_count = pass_count + 1;
      end else begin
        $display("FAIL [%0s]:", tname);
        $display("       expected = 128'h%032H", golden);
        $display("       got      = 128'h%032H", got);
        fail_count = fail_count + 1;
      end

      // Drain: let pipeline empty before next test
      repeat(3) @(posedge iClk);
    end
  endtask

  //--------------------------------------------------------------------
  // Main sequence
  //--------------------------------------------------------------------
  integer t;

  initial begin
    $dumpfile("tb_SubBytesEnc.vcd");
    $dumpvars(0, tb_SubBytesEnc);

    $display("================================================");
    $display("  SubBytesEnc Testbench  (200 MHz)             ");
    $display("================================================");

    // Reset
    iReset = 0;
    repeat(3) @(posedge iClk);
    iReset = 1;
    repeat(2) @(posedge iClk);

    // Reset check
    $display("\n-- Reset check --");
    if (oValid !== 1'b0)
      $display("FAIL: oValid not cleared after reset");
    else
      $display("PASS: oValid=0 after reset");

    // Run all vectors
    $display("\n-- Functional vectors --");
    for (t = 0; t < NUM_TESTS; t = t + 1)
      drive_and_check(tv_in[t], tv_gold[t], tv_name[t]);

    // Latency report
    $display("\n-- Latency --");
    $display("  iReady first seen at cycle : %0d", ready_cycle);
    $display("  oValid first seen at cycle : %0d", valid_cycle);
    $display("  Pipeline latency           : %0d cycles", valid_cycle - ready_cycle);
    $display("  At 200 MHz                 : %0d ns",
             (valid_cycle - ready_cycle) * 5);
    if (valid_cycle - ready_cycle == 2)
      $display("  (expected: 2 cycles — BRAM read + valid register)");
    else
      $display("  (unexpected latency — check RAM inference in synthesis log)");

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

  initial begin #50000; $display("WATCHDOG TIMEOUT"); $finish; end

endmodule
