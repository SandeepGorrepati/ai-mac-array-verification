`timescale 1ns/1ps
module tb_stream;
  parameter N=4, OUT_W=16;
  reg clk=0,rst_n=0,in_valid=0;
  always #5 clk=~clk;
  reg [N*N*8-1:0] a_flat=0,b_flat=0;
  wire out_valid;
  wire [N*N*OUT_W-1:0] c_flat;
  wire [N*N-1:0] ovf;
  mac_array_4x4 #(.N(N),.OUT_W(OUT_W)) dut(.*);
  integer fd,rc,rv,iv,cycles=0,checked=0;
  reg pv=0;
  reg [N*N*OUT_W-1:0] expected,previous;
  reg [N*N-1:0] eo,po;
  initial begin
    fd=$fopen("build/stream.txt","r");
    if(!fd) $fatal(1,"oracle file missing");
    while(!$feof(fd)) begin
      @(negedge clk);
      rc=$fscanf(fd,"%h %h %h %h %h %h\n",rv,iv,a_flat,b_flat,expected,eo);
      if(rc!=6) $fatal(1,"bad vector");
      rst_n=rv[0]; in_valid=iv[0];
      @(posedge clk); #1;
      if(!rst_n) begin
        if(out_valid !== 0) $fatal(1,"reset valid");
        pv=0;
      end else begin
        if(out_valid !== pv) $fatal(1,"latency/bubble cycle=%0d",cycles);
        if(pv) begin
          if(c_flat !== previous || ovf !== po) $fatal(1,"Python oracle mismatch cycle=%0d",cycles);
          checked=checked+1;
        end
        pv=in_valid; previous=expected; po=eo;
      end
      cycles=cycles+1;
    end
    if(pv) $fatal(1,"oracle stream did not drain");
    $display("PASS: Python oracle cycles=%0d checked=%0d N=%0d OUT_W=%0d; streaming, bubbles, reset",cycles,checked,N,OUT_W);
    $finish;
  end
  initial begin #100000; $fatal(1,"stream timeout"); end
endmodule
