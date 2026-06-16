//==============================================================================
// tb_mac_array.sv
// Self-checking testbench for the 4x4 signed MAC matrix-multiply accelerator.
// Independent reference model (nested-loop matmul + saturation), directed corner
// cases (zeros / identity / max / min / mixed), constrained-random tests, a
// functional-coverage covergroup, and a PASS/FAIL summary.
//
// Runs on any SV simulator; covergroups need Questa/VCS/Xcelium (e.g. EDA Playground).
//==============================================================================
`timescale 1ns/1ps

module tb_mac_array;
    localparam int N = 4;

    logic                 clk, rst_n, in_valid, out_valid;
    logic [N*N*8-1:0]     a_flat, b_flat;
    logic [N*N*16-1:0]    c_flat;
    logic [N*N-1:0]       ovf;

    mac_array_4x4 dut(.clk(clk), .rst_n(rst_n), .in_valid(in_valid),
                      .a_flat(a_flat), .b_flat(b_flat),
                      .out_valid(out_valid), .c_flat(c_flat), .ovf(ovf));

    initial clk = 0;  always #5 clk = ~clk;

    // current test operands + expected
    logic signed [7:0]  A [0:N-1][0:N-1], B [0:N-1][0:N-1];
    logic signed [15:0] exp_c [0:N-1][0:N-1];
    logic [N*N-1:0]     exp_ov;

    int passes, fails, sat_seen;

    // ---- functional coverage ----
    bit any_sat; int c00_sign;
    covergroup cg @(posedge clk iff out_valid);
        cp_sat  : coverpoint any_sat { bins none={0}; bins some={1}; }
        cp_sign : coverpoint c00_sign { bins neg={-1}; bins zero={0}; bins pos={1}; }
        x       : cross cp_sat, cp_sign;
    endgroup
    cg cov = new();

    // ---- independent reference: C = saturate16(A x B) ----
    task automatic compute_ref();
        int acc;
        exp_ov = '0;
        for (int i=0;i<N;i++) for (int j=0;j<N;j++) begin
            acc = 0;
            for (int k=0;k<N;k++) acc += A[i][k]*B[k][j];
            if (acc > 32767)       begin exp_c[i][j]=16'sd32767;  exp_ov[i*N+j]=1; end
            else if (acc < -32768) begin exp_c[i][j]=-16'sd32768; exp_ov[i*N+j]=1; end
            else                         exp_c[i][j]=acc[15:0];
        end
    endtask

    task automatic pack();
        for (int i=0;i<N;i++) for (int k=0;k<N;k++) begin
            a_flat[(i*N+k)*8 +: 8] = A[i][k];
            b_flat[(i*N+k)*8 +: 8] = B[i][k];
        end
    endtask

    // drive one matrix pair, wait for result, self-check
    task automatic run_test(string name);
        logic signed [15:0] got;
        bit ok; int nsat;
        compute_ref(); pack();
        @(posedge clk); in_valid <= 1'b1;
        @(posedge clk); in_valid <= 1'b0;
        wait (out_valid);
        #1;
        ok = 1; nsat = 0;
        for (int i=0;i<N;i++) for (int j=0;j<N;j++) begin
            got = c_flat[(i*N+j)*16 +: 16];
            if (got !== exp_c[i][j]) ok = 0;
            if (ovf[i*N+j] !== exp_ov[i*N+j]) ok = 0;
            if (exp_ov[i*N+j]) nsat++;
        end
        // coverage sampling vars
        any_sat  = (|exp_ov);
        c00_sign = (exp_c[0][0] < 0) ? -1 : (exp_c[0][0]==0 ? 0 : 1);
        if (nsat>0) sat_seen++;
        if (ok) begin passes++; $display("[PASS] %-10s c[0][0]=%0d sat=%0d/16", name, exp_c[0][0], nsat); end
        else   begin fails++;  $display("[FAIL] %-10s mismatch (see waves)", name); end
    endtask

    task automatic set_const(input signed [7:0] va, vb);
        for (int i=0;i<N;i++) for (int j=0;j<N;j++) begin A[i][j]=va; B[i][j]=vb; end
    endtask
    task automatic set_ident_B();
        for (int i=0;i<N;i++) for (int j=0;j<N;j++) B[i][j]=(i==j)?8'sd1:8'sd0;
    endtask
    task automatic randomize_AB();
        for (int i=0;i<N;i++) for (int j=0;j<N;j++) begin
            A[i][j]=$urandom_range(0,255); B[i][j]=$urandom_range(0,255);
        end
    endtask

    initial begin
        in_valid=0; rst_n=0; a_flat=0; b_flat=0;
        repeat(3) @(posedge clk); rst_n=1; @(posedge clk);

        // directed corners
        set_const(0,0);                              run_test("zeros");
        for (int i=0;i<N;i++) for (int j=0;j<N;j++) A[i][j]=i*N+j-8; set_ident_B(); run_test("AxI");
        set_const(127,127);                          run_test("max_sat");   // saturates high
        set_const(-128,127);                         run_test("min_sat");   // saturates low
        set_const(10,-3);                            run_test("small_neg");

        // constrained-random
        for (int t=0;t<60;t++) begin randomize_AB(); run_test($sformatf("rand%0d",t)); end

        repeat(3) @(posedge clk);
        $display("==================================================");
        $display("MAC-ARRAY VERIFICATION SUMMARY");
        $display("  tests=%0d  PASS=%0d  FAIL=%0d  saturating-tests=%0d", passes+fails, passes, fails, sat_seen);
        $display("  Functional coverage = %0.2f%%", cov.get_inst_coverage());
        $display("  RESULT: %s", (fails==0)?"PASS":"FAIL");
        $display("==================================================");
        $finish;
    end

    initial begin $dumpfile("mac_array.vcd"); $dumpvars(0,tb_mac_array); end
    initial begin #200000; $display("TIMEOUT"); $finish; end
endmodule
