`timescale 1ns / 1ps

module tb_MixColumnsEnc;

  reg          iClk     = 0;
  reg          iReset   = 0;
  reg          iReady   = 0;
  reg  [127:0] iBlockIn = 0;
  reg          iRound   = 1;

  wire         oValid;
  wire [127:0] oBlockOut;

  always #2.5 iClk = ~iClk;  // 200 MHz

  MixColumnsEnc dut (
    .iClk     (iClk),
    .iReset   (iReset),
    .iReady   (iReady),
    .oValid   (oValid),
    .iBlockIn (iBlockIn),
    .oBlockOut(oBlockOut),
    .iRound   (iRound)
  );

  initial begin
    $dumpfile("tb_MixColumnsEnc.vcd");
    $dumpvars(0, tb_MixColumnsEnc);

    // Reset
    iReset = 0;
    repeat(3) @(posedge iClk);
    iReset = 1;
    repeat(2) @(posedge iClk);

    // Test 1: FIPS known column
    @(negedge iClk);
    iBlockIn <= 128'hD4BF5D30D4BF5D30D4BF5D30D4BF5D30;
    iReady   <= 1;
    iRound   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(5) @(posedge iClk);

    // Test 2: incrementing bytes
    @(negedge iClk);
    iBlockIn <= 128'h000102030405060708090A0B0C0D0E0F;
    iReady   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(5) @(posedge iClk);

    // Test 3: DEADBEEF
    @(negedge iClk);
    iBlockIn <= 128'hDEADBEEFCAFEBABE0102030405060708;
    iReady   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(5) @(posedge iClk);

    // Test 4: iRound=0 bypass
    @(negedge iClk);
    iBlockIn <= 128'hABCDEF0123456789AABBCCDDEEFF0011;
    iReady   <= 1;
    iRound   <= 0;
    @(negedge iClk);
    iReady <= 0;
    iRound <= 1;
    repeat(5) @(posedge iClk);

    // Test 5: back-to-back, no gap between inputs
    @(negedge iClk);
    iBlockIn <= 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
    iReady   <= 1;
    iRound   <= 1;
    @(negedge iClk);
    iBlockIn <= 128'h12345678DEADBEEF12345678DEADBEEF;
    iReady   <= 1;
    @(negedge iClk);
    iReady <= 0;
    repeat(6) @(posedge iClk);

    $display("Simulation done. Check waveform for oValid and oBlockOut.");
    $finish;
  end

  // Print every time valid output appears
  always @(posedge iClk)
    if (oValid)
      $display("[%0t ns] oValid=1  oBlockOut=128'h%032H", $time/1000, oBlockOut);

endmodule