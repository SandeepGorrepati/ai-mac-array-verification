// Coverage-instrumented testbench: tracks functional-coverage bins manually so a
// real coverage number is produced on Icarus (which does not score covergroups).
// Mirrors the covergroup in tb/tb_mac_array.sv: cp_sat(2) x cp_sign(3) + cross(6).
`timescale 1ns/1ps
module tb_mac_cov;
  localparam int N=4;
  logic clk=0, rst_n, in_valid, out_valid;
  logic [N*N*8-1:0] a_flat,b_flat; logic [N*N*16-1:0] c_flat; logic [N*N-1:0] ovf;
  mac_array_4x4 dut(.clk,.rst_n,.in_valid,.a_flat,.b_flat,.out_valid,.c_flat,.ovf);
  always #5 clk=~clk;
  logic signed [7:0] A[0:N-1][0:N-1], B[0:N-1][0:N-1];
  logic signed [15:0] exp_c[0:N-1][0:N-1]; logic [N*N-1:0] exp_ov;
  int passes,fails;
  // manual coverage bins
  bit hit_sat[0:1]; bit hit_sign[0:2]; bit hit_cross[0:1][0:2];

  task automatic compute_ref(); int acc; exp_ov='0;
    for(int i=0;i<N;i++)for(int j=0;j<N;j++)begin acc=0;
      for(int k=0;k<N;k++) acc+=A[i][k]*B[k][j];
      if(acc>32767)begin exp_c[i][j]=16'sd32767; exp_ov[i*N+j]=1; end
      else if(acc<-32768)begin exp_c[i][j]=-16'sd32768; exp_ov[i*N+j]=1; end
      else exp_c[i][j]=acc[15:0]; end
  endtask
  task automatic pack(); for(int i=0;i<N;i++)for(int k=0;k<N;k++)begin
      a_flat[(i*N+k)*8+:8]=A[i][k]; b_flat[(i*N+k)*8+:8]=B[i][k]; end endtask
  task automatic run_test(string nm); logic signed[15:0] got; bit ok; int sat; bit anysat; int sgn;
    compute_ref(); pack(); @(posedge clk) in_valid<=1; @(posedge clk) in_valid<=0;
    wait(out_valid); #1; ok=1; sat=0;
    for(int i=0;i<N;i++)for(int j=0;j<N;j++)begin got=c_flat[(i*N+j)*16+:16];
      if(got!==exp_c[i][j])ok=0; if(ovf[i*N+j]!==exp_ov[i*N+j])ok=0; if(exp_ov[i*N+j])sat++; end
    anysat=(|exp_ov); sgn=(exp_c[0][0]<0)?0:(exp_c[0][0]==0?1:2);
    hit_sat[anysat]=1; hit_sign[sgn]=1; hit_cross[anysat][sgn]=1;
    if(ok)passes++; else fails++;
  endtask
  task automatic set_const(input signed[7:0] va,vb); for(int i=0;i<N;i++)for(int j=0;j<N;j++)begin A[i][j]=va;B[i][j]=vb;end endtask
  task automatic ident_B(); for(int i=0;i<N;i++)for(int j=0;j<N;j++)B[i][j]=(i==j)?8'sd1:8'sd0; endtask

  initial begin int cs,cg,cx,tot; real pct;
    in_valid=0;rst_n=0;a_flat=0;b_flat=0; repeat(3)@(posedge clk); rst_n=1; @(posedge clk);
    set_const(0,0); run_test("zeros");
    for(int i=0;i<N;i++)for(int j=0;j<N;j++)A[i][j]=i*N+j-8; ident_B(); run_test("AxI");
    set_const(127,127); run_test("max_sat");
    set_const(-128,127); run_test("min_sat");
    set_const(10,-3); run_test("small_neg");
    // crafted: make c[0][0]==0 while another element saturates (targets cross some/zero)
    for(int i=0;i<N;i++)for(int j=0;j<N;j++)begin A[i][j]=0;B[i][j]=0;end
    A[1][0]=127;A[1][1]=127;A[1][2]=127; B[0][1]=127;B[1][1]=127;B[2][1]=127; // c[1][1]=3*127*127 saturates; c[0][0]=0
    run_test("sat_with_c00_zero");
    for(int t=0;t<60;t++)begin for(int i=0;i<N;i++)for(int j=0;j<N;j++)begin
      A[i][j]=$urandom_range(0,255);B[i][j]=$urandom_range(0,255);end run_test($sformatf("rand%0d",t)); end
    cs=0; foreach(hit_sat[i])cs+=hit_sat[i];
    cg=0; foreach(hit_sign[i])cg+=hit_sign[i];
    cx=0; for(int a=0;a<2;a++)for(int s=0;s<3;s++)cx+=hit_cross[a][s];
    tot=cs+cg+cx; pct=100.0*tot/11.0;
    $display("==================================================");
    $display("MAC FUNCTIONAL COVERAGE (manual bin tracking, Icarus)");
    $display("  cp_sat   : %0d/2 bins", cs);
    $display("  cp_sign  : %0d/3 bins", cg);
    $display("  cross    : %0d/6 bins", cx);
    $display("  TOTAL    : %0d/11 bins = %0.1f%%", tot, pct);
    $display("  tests=%0d PASS=%0d FAIL=%0d", passes+fails, passes, fails);
    $display("==================================================");
    $finish;
  end
  initial begin #300000; $finish; end
endmodule
