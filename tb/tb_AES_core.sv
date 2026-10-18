`timescale 1ns / 1ps
//==============================================================================
// Testbench : tb_AES_core (simple version)
// DUT       : AES_core (pipelined AES-128 encryption core)
//
//   - Applies one FIPS-197 Appendix B / C.1 known-answer vector
//   - Measures pipeline latency: cycles from the iReady pulse to oValid
//   - Checks data integrity with a single SVA: whenever oValid is high,
//     oCiphertext must equal the FIPS-197 expected ciphertext
//
// Reset: DUT sub-modules use `always @(posedge iClk or negedge iReset)
// if (~iReset)` -> iReset is ASYNC, ACTIVE-LOW.
//==============================================================================

module tb_AES_core;

    localparam time CLK_PERIOD = 10ns;

    logic iClk;
    logic iReset;                 // async, active-low

    initial iClk = 1'b0;
    always #(CLK_PERIOD/2) iClk = ~iClk;

    //--------------------------------------------------------------------
    // DUT I/O
    //--------------------------------------------------------------------
    logic  [127:0] iPlaintext;
    logic  [127:0] iKey;
    logic          iReady;
    wire   [127:0] oCiphertext;
    wire           oValid;

    AES_core dut (
        .oCiphertext (oCiphertext),
        .oValid      (oValid),
        .iClk        (iClk),
        .iReset      (iReset),
        .iPlaintext  (iPlaintext),
        .iKey        (iKey),
        .iReady      (iReady)
    );

    //--------------------------------------------------------------------
    // FIPS-197 Appendix B / C.1 known-answer vector (AES-128)
    //--------------------------------------------------------------------
    localparam logic [127:0] KEY = 128'h000102030405060708090a0b0c0d0e0f;
    localparam logic [127:0] PT  = 128'h00112233445566778899aabbccddeeff;
    localparam logic [127:0] CT  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    //--------------------------------------------------------------------
    // Stimulus + latency measurement
    //--------------------------------------------------------------------
    int unsigned cycle_count;
    int unsigned start_cycle, valid_cycle, latency;

    always @(posedge iClk or negedge iReset)
        if (!iReset) cycle_count <= 0;
        else         cycle_count <= cycle_count + 1;

    initial begin
        iReady     = 1'b0;
        iKey       = KEY;
        iPlaintext = PT;

        // async active-low reset
        iReset = 1'b0;
        repeat (4) @(posedge iClk);
        iReset = 1'b1;
        repeat (2) @(posedge iClk);

        // single-cycle start pulse
        @(posedge iClk);
        iReady = 1'b1;
        @(posedge iClk);
        start_cycle = cycle_count;   // cycle at which iReady=1 is sampled
        iReady = 1'b0;

        // wait for result
        while (oValid !== 1'b1) @(posedge iClk);
        valid_cycle = cycle_count;
        latency     = valid_cycle - start_cycle;

        $display("Latency        = %0d cycles", latency);
        $display("Expected CT    = %032h", CT);
        $display("Got CT         = %032h", oCiphertext);

        if (oCiphertext === CT)
            $display("*** PASS: ciphertext matches FIPS-197 vector ***");
        else
            $error("*** FAIL: ciphertext mismatch ***");

        repeat (5) @(posedge iClk);
        $finish;
    end

    // watchdog
    initial begin
        #100000;
        $error("WATCHDOG TIMEOUT - oValid never asserted");
        $finish;
    end

    //--------------------------------------------------------------------
    // SVA: data integrity check against the FIPS-197 vector
    //--------------------------------------------------------------------
    property p_data_integrity;
        @(posedge iClk) disable iff (!iReset)
        oValid |-> (oCiphertext == CT);
    endproperty
    assert property (p_data_integrity)
        else $error("SVA p_data_integrity: oCiphertext != FIPS-197 expected CT @ %0t", $time);

endmodule


/*`timescale 1ns / 1ps
//==============================================================================
// SVA Testbench: tb_AES_core_sva  (rewritten — no hangs)
//
// DUT: AES_core (fully pipelined AES-128)
//
// !! IMPORTANT BUG NOTE !!
//   InputRegsEnc has port  iNewKey  that AES_core never connects.
//   Because iNewKey is always 0, the key register inside InputRegsEnc
//   is NEVER loaded. All functional / KAT tests will fail until either:
//     (a) AES_core exposes and drives an  iNewKey  top-level port, OR
//     (b) InputRegsEnc is changed to always capture the key when iReady fires.
//   Structural / latency SVA assertions fire correctly regardless.
//
// Latency breakdown (confirmed from RTL):
//   InputRegsEnc    : 1 cycle
//   AddRoundKeyEnc  : 1 cycle  (initial key whitening)
//   Round x9        : 4 cycles each  (SubBytes=1, ShiftRows=0, MixCols=2, ARK=1)
//   FinalRound      : 4 cycles  (MixCols bypass still 2 cycles via bypass_r2)
//   TOTAL           : 1 + 1 + 9*4 + 4 = 42 cycles
//
// Root causes of previous hang fixed here:
//   1. 'break' inside 'repeat' removed  -> replaced with integer flag + for loop
//   2. 'typedef struct' with queue removed -> replaced with plain logic variables
//   3. Loop-variable scope issue fixed   -> declared at module level as integer
//   4. All tasks use only @(negedge)/@(posedge) + repeat(N) — no dynamic waits
//==============================================================================

`define PIPE_LATENCY  42
`define ROUND_LAT      4
`define ARK0_LAT       2

module tb_AES_core;

    //--------------------------------------------------------------------------
    // Clock and DUT ports
    //--------------------------------------------------------------------------
    logic        iClk      = 0;
    logic        iReset    = 0;
    logic [127:0] iPlaintext = '0;
    logic [127:0] iKey       = '0;
    logic        iReady    = 0;

    wire [127:0] oCiphertext;
    wire         oValid;

    always #2.5 iClk = ~iClk;   // 200 MHz

    AES_core dut (
        .iClk       (iClk),
        .iReset     (iReset),
        .iPlaintext (iPlaintext),
        .iKey       (iKey),
        .iReady     (iReady),
        .oCiphertext(oCiphertext),
        .oValid     (oValid)
    );

    //--------------------------------------------------------------------------
    // Tap internal handshake wires for structural assertions
    //--------------------------------------------------------------------------
    wire wValidInit = dut.wValidInit;
    wire wValid1    = dut.wValid1;
    wire wValid2    = dut.wValid2;
    wire wValid3    = dut.wValid3;
    wire wValid4    = dut.wValid4;
    wire wValid5    = dut.wValid5;
    wire wValid6    = dut.wValid6;
    wire wValid7    = dut.wValid7;
    wire wValid8    = dut.wValid8;
    wire wValid9    = dut.wValid9;

    //--------------------------------------------------------------------------
    // Cycle counter — visible in waveform window
    //--------------------------------------------------------------------------
    integer cycle_count = 0;
    always @(posedge iClk) cycle_count <= cycle_count + 1;

    //--------------------------------------------------------------------------
    // Pass/fail counters (module-level so tasks can reach them without issues)
    //--------------------------------------------------------------------------
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // Loop variable declared at module level to avoid Xsim scope issues
    integer w;

    //==========================================================================
    // SVA PROPERTIES
    //==========================================================================

    // P1 — oValid stays low during reset
    property p_reset_clears_valid;
        @(posedge iClk) !iReset |-> !oValid;
    endproperty
    AP1_reset : assert property (p_reset_clears_valid)
        else $error("[SVA FAIL P1] oValid high during reset  cycle=%0d", cycle_count);

    // P2 — oValid must arrive exactly 42 cycles after iReady rises
    property p_latency;
        @(posedge iClk) disable iff (!iReset)
        $rose(iReady) |-> ##`PIPE_LATENCY oValid;
    endproperty
    AP2_latency : assert property (p_latency)
        else $error("[SVA FAIL P2] oValid not at cycle+42 after iReady  cycle=%0d",
                    cycle_count);

    // P3 — No oValid before cycle 42 (no early fire)
    property p_no_early;
        @(posedge iClk) disable iff (!iReset)
        $rose(iReady) |-> ##[1:`PIPE_LATENCY-1] !oValid;
    endproperty
    AP3_no_early : assert property (p_no_early)
        else $error("[SVA FAIL P3] oValid fired too early  cycle=%0d", cycle_count);

    // P4 — Two consecutive iReady pulses produce two consecutive oValid
    property p_throughput;
        @(posedge iClk) disable iff (!iReset)
        (iReady ##1 iReady) |-> ##(`PIPE_LATENCY - 1) (oValid ##1 oValid);
    endproperty
    AP4_throughput : assert property (p_throughput)
        else $error("[SVA FAIL P4] Pipeline throughput broken  cycle=%0d", cycle_count);

    // P5 — wValidInit appears exactly 2 cycles after iReady
    property p_ark0;
        @(posedge iClk) disable iff (!iReset)
        $rose(iReady) |-> ##`ARK0_LAT wValidInit;
    endproperty
    AP5_ark0 : assert property (p_ark0)
        else $error("[SVA FAIL P5] wValidInit not 2 cycles after iReady  cycle=%0d",
                    cycle_count);

    // P6a-P6j — Each round stage: exactly 4-cycle latency on its handshake
    property p_round_lat (logic src, logic dst);
        @(posedge iClk) disable iff (!iReset)
        $rose(src) |-> ##`ROUND_LAT dst;
    endproperty

    AP6a : assert property (p_round_lat(wValidInit, wValid1))
        else $error("[SVA FAIL P6a] R1 latency != 4");
    AP6b : assert property (p_round_lat(wValid1,    wValid2))
        else $error("[SVA FAIL P6b] R2 latency != 4");
    AP6c : assert property (p_round_lat(wValid2,    wValid3))
        else $error("[SVA FAIL P6c] R3 latency != 4");
    AP6d : assert property (p_round_lat(wValid3,    wValid4))
        else $error("[SVA FAIL P6d] R4 latency != 4");
    AP6e : assert property (p_round_lat(wValid4,    wValid5))
        else $error("[SVA FAIL P6e] R5 latency != 4");
    AP6f : assert property (p_round_lat(wValid5,    wValid6))
        else $error("[SVA FAIL P6f] R6 latency != 4");
    AP6g : assert property (p_round_lat(wValid6,    wValid7))
        else $error("[SVA FAIL P6g] R7 latency != 4");
    AP6h : assert property (p_round_lat(wValid7,    wValid8))
        else $error("[SVA FAIL P6h] R8 latency != 4");
    AP6i : assert property (p_round_lat(wValid8,    wValid9))
        else $error("[SVA FAIL P6i] R9 latency != 4");
    AP6j : assert property (p_round_lat(wValid9,    oValid))
        else $error("[SVA FAIL P6j] FinalRound latency != 4");

    // P7 — No X/Z on oCiphertext when oValid is high
    property p_no_x;
        @(posedge iClk) disable iff (!iReset)
        oValid |-> (^oCiphertext !== 1'bx);
    endproperty
    AP7_no_x : assert property (p_no_x)
        else $error("[SVA FAIL P7] oCiphertext has X/Z when oValid=1  cycle=%0d",
                    cycle_count);

    //==========================================================================
    // FIPS-197 Known-Answer Test Vectors
    //==========================================================================

    // FIPS-197 Appendix B
    localparam [127:0] FIPS_B_PT  = 128'h3243F6A8_885A308D_313198A2_E0370734;
    localparam [127:0] FIPS_B_KEY = 128'h2B7E1516_28AED2A6_ABF71588_09CF4F3C;
    localparam [127:0] FIPS_B_CT  = 128'h3925841D_02DC09FB_DC118597_196A0B32;

    // FIPS-197 Appendix C.1 (AES-128)
    localparam [127:0] FIPS_C_PT  = 128'h00112233_44556677_8899AABB_CCDDEEFF;
    localparam [127:0] FIPS_C_KEY = 128'h00010203_04050607_08090A0B_0C0D0E0F;
    localparam [127:0] FIPS_C_CT  = 128'h69C4E0D8_6A7B0430_D8CDB780_70B4C55A;

    // Anti-alias pair: same key, 1-bit different plaintexts
    localparam [127:0] ALIAS_PT1  = 128'hDEADBEEF_CAFEBABE_01020304_05060708;
    localparam [127:0] ALIAS_PT2  = 128'hDEADBEEF_CAFEBABE_01020304_05060709;
    localparam [127:0] ALIAS_KEY  = FIPS_B_KEY;

    //==========================================================================
    // MAIN STIMULUS — no break, no struct, no dynamic wait loops
    //==========================================================================
    logic [127:0] ct_a, ct_b;
    logic         va, vb;
    integer       start_cyc, end_cyc, measured, found;
    integer       valid_count;

    initial begin
        $dumpfile("tb_AES_core.vcd");
        $dumpvars(0, tb_AES_core);

        $display("=========================================================");
        $display("  AES_core SVA Testbench");
        $display("=========================================================");
        $display("  NOTE: InputRegsEnc.iNewKey unconnected in AES_core.");
        $display("  Key is never latched -> T1/T2 KAT will FAIL until fixed.");
        $display("  Pipeline/structural assertions (SVA) run regardless.");
        $display("=========================================================\n");

        //--------------------------------------------------------------
        // Reset
        //--------------------------------------------------------------
        iReset = 0; iReady = 0;
        repeat(4) @(posedge iClk);
        iReset = 1;
        repeat(2) @(posedge iClk);
        $display("[INFO] Reset released  cycle=%0d", cycle_count);

        //--------------------------------------------------------------
        // T1 — FIPS-197 Appendix B
        //--------------------------------------------------------------
        $display("\n[T1] FIPS-197 Appendix B  (42-cycle fixed wait)");
        $display("     PT =%h", FIPS_B_PT);
        $display("     KEY=%h", FIPS_B_KEY);
        $display("     EXP=%h", FIPS_B_CT);

        @(negedge iClk);
        iPlaintext <= FIPS_B_PT; iKey <= FIPS_B_KEY; iReady <= 1;
        @(negedge iClk); iReady <= 0;
        repeat(`PIPE_LATENCY) @(posedge iClk);
        ct_a = oCiphertext; va = oValid;

        if (!va)
            $display("  FAIL  oValid not asserted at cycle %0d", cycle_count);
        else if (^ct_a === 1'bx)
            $display("  FAIL  oCiphertext is X");
        else if (ct_a !== FIPS_B_CT) begin
            $display("  FAIL  got=%h  exp=%h", ct_a, FIPS_B_CT);
            fail_cnt = fail_cnt + 1;
        end else begin
            $display("  PASS  ct=%h", ct_a);
            pass_cnt = pass_cnt + 1;
        end
        repeat(5) @(posedge iClk);

        //--------------------------------------------------------------
        // T2 — FIPS-197 Appendix C.1
        //--------------------------------------------------------------
        $display("\n[T2] FIPS-197 Appendix C.1");
        $display("     PT =%h", FIPS_C_PT);
        $display("     KEY=%h", FIPS_C_KEY);
        $display("     EXP=%h", FIPS_C_CT);

        @(negedge iClk);
        iPlaintext <= FIPS_C_PT; iKey <= FIPS_C_KEY; iReady <= 1;
        @(negedge iClk); iReady <= 0;
        repeat(`PIPE_LATENCY) @(posedge iClk);
        ct_b = oCiphertext; vb = oValid;

        if (!vb)
            $display("  FAIL  oValid not asserted at cycle %0d", cycle_count);
        else if (^ct_b === 1'bx)
            $display("  FAIL  oCiphertext is X");
        else if (ct_b !== FIPS_C_CT) begin
            $display("  FAIL  got=%h  exp=%h", ct_b, FIPS_C_CT);
            fail_cnt = fail_cnt + 1;
        end else begin
            $display("  PASS  ct=%h", ct_b);
            pass_cnt = pass_cnt + 1;
        end
        repeat(5) @(posedge iClk);

        //--------------------------------------------------------------
        // T3 — Determinism: same block twice → same CT
        //--------------------------------------------------------------
        $display("\n[T3] Determinism (same block twice)");

        @(negedge iClk); iPlaintext <= FIPS_B_PT; iKey <= FIPS_B_KEY; iReady <= 1;
        @(negedge iClk); iReady <= 0;
        repeat(`PIPE_LATENCY) @(posedge iClk);
        ct_a = oCiphertext; va = oValid;
        repeat(5) @(posedge iClk);

        @(negedge iClk); iPlaintext <= FIPS_B_PT; iKey <= FIPS_B_KEY; iReady <= 1;
        @(negedge iClk); iReady <= 0;
        repeat(`PIPE_LATENCY) @(posedge iClk);
        ct_b = oCiphertext; vb = oValid;

        if (!va || !vb) begin
            $display("  FAIL  oValid missing on one copy");
            fail_cnt = fail_cnt + 1;
        end else if (ct_a === ct_b) begin
            $display("  PASS  determinism: ct=%h", ct_a);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  ct1=%h  ct2=%h", ct_a, ct_b);
            fail_cnt = fail_cnt + 1;
        end
        repeat(5) @(posedge iClk);

        //--------------------------------------------------------------
        // T4 — Throughput: 4 back-to-back blocks → 4 back-to-back oValid
        //      Module-level 'w' and 'valid_count' avoid scope issues.
        //--------------------------------------------------------------
        $display("\n[T4] Pipeline throughput (4 consecutive blocks)");
        valid_count = 0;

        @(negedge iClk); iReady <= 1; iPlaintext <= FIPS_B_PT; iKey <= FIPS_B_KEY;
        @(negedge iClk);              iPlaintext <= FIPS_C_PT; iKey <= FIPS_C_KEY;
        @(negedge iClk);              iPlaintext <= ALIAS_PT1; iKey <= ALIAS_KEY;
        @(negedge iClk);              iPlaintext <= ALIAS_PT2; iKey <= ALIAS_KEY;
        @(negedge iClk); iReady <= 0;

        for (w = 0; w < `PIPE_LATENCY + 6; w = w + 1) begin
            @(posedge iClk);
            if (oValid) valid_count = valid_count + 1;
        end

        if (valid_count == 4) begin
            $display("  PASS  got %0d consecutive oValid pulses", valid_count);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  expected 4 oValid, got %0d", valid_count);
            fail_cnt = fail_cnt + 1;
        end
        repeat(5) @(posedge iClk);

        //--------------------------------------------------------------
        // T5 — Anti-aliasing: 1-bit different PT must give different CT
        //--------------------------------------------------------------
        $display("\n[T5] Anti-aliasing (PT differ by 1 bit, same key)");

        @(negedge iClk); iPlaintext <= ALIAS_PT1; iKey <= ALIAS_KEY; iReady <= 1;
        @(negedge iClk); iReady <= 0;
        repeat(`PIPE_LATENCY) @(posedge iClk);
        ct_a = oCiphertext; va = oValid;
        repeat(5) @(posedge iClk);

        @(negedge iClk); iPlaintext <= ALIAS_PT2; iKey <= ALIAS_KEY; iReady <= 1;
        @(negedge iClk); iReady <= 0;
        repeat(`PIPE_LATENCY) @(posedge iClk);
        ct_b = oCiphertext; vb = oValid;

        if (!va || !vb) begin
            $display("  FAIL  oValid missing");
            fail_cnt = fail_cnt + 1;
        end else if (ct_a !== ct_b) begin
            $display("  PASS  PT1 ct=%h", ct_a);
            $display("        PT2 ct=%h  (different — good)", ct_b);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL  different PTs gave same CT: %h", ct_a);
            fail_cnt = fail_cnt + 1;
        end
        repeat(5) @(posedge iClk);

        //--------------------------------------------------------------
        // T6 — Latency measurement: count cycles from iReady → oValid
        //      'found' flag replaces 'break'; module-level 'w' used.
        //--------------------------------------------------------------
        $display("\n[T6] Latency measurement");
        found = 0; start_cyc = 0; end_cyc = 0;

        @(negedge iClk); iPlaintext <= FIPS_C_PT; iKey <= FIPS_C_KEY; iReady <= 1;
        @(posedge iClk); start_cyc = cycle_count;   // record start
        @(negedge iClk); iReady <= 0;

        for (w = 0; w < `PIPE_LATENCY + 10; w = w + 1) begin
            @(posedge iClk);
            if (oValid && !found) begin
                end_cyc = cycle_count;
                found   = 1;
            end
        end

        if (!found) begin
            $display("  FAIL  oValid never fired within %0d cycles",
                     `PIPE_LATENCY + 10);
            fail_cnt = fail_cnt + 1;
        end else begin
            measured = end_cyc - start_cyc;
            $display("  start=%0d  end=%0d  measured=%0d  expected=%0d",
                     start_cyc, end_cyc, measured, `PIPE_LATENCY);
            if (measured == `PIPE_LATENCY) begin
                $display("  PASS  latency = %0d cycles", measured);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL  latency = %0d, expected %0d",
                         measured, `PIPE_LATENCY);
                fail_cnt = fail_cnt + 1;
            end
        end
        repeat(5) @(posedge iClk);

        //--------------------------------------------------------------
        // Summary
        //--------------------------------------------------------------
        repeat(10) @(posedge iClk);
        $display("\n=========================================================");
        $display("  Stimulus : %0d PASSED   %0d FAILED", pass_cnt, fail_cnt);
        $display("  SVA      : check above for [SVA FAIL] messages");
        $display("=========================================================");
        if (fail_cnt == 0)
            $display("  ALL STIMULUS TESTS PASSED");
        else begin
            $display("  SOME TESTS FAILED");
            $display("  If T1/T2 failed: connect iNewKey in AES_core first.");
        end
        $finish;
    end

    // Watchdog — catches any genuine infinite loop
    initial begin
        #5_000_000;
        $display("[WATCHDOG] Exceeded time limit");
        $finish;
    end

endmodule*/