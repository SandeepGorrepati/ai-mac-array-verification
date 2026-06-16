//==============================================================================
// mac_array_4x4.sv
// 4x4 signed MAC matrix-multiply accelerator (the compute core of an AI/ML
// systolic/MAC engine, scaled down for clean verification).
//
//   C = saturate16( A x B )
//   A, B : 4x4 matrices of signed 8-bit elements (flattened, row-major)
//   C    : 4x4 matrix of signed 16-bit elements; each element is the dot product
//          of an A-row and a B-column, accumulated exactly (20-bit) then saturated
//          to signed 16-bit. A per-element overflow flag marks saturation.
//
// 2-stage pipeline: latch inputs (valid) -> compute+saturate -> register outputs.
//==============================================================================
`timescale 1ns/1ps

module mac_array_4x4 #(
    parameter int N     = 4,
    parameter int IN_W  = 8,
    parameter int ACC_W = 20,   // holds sum of 4 signed 8x8 products (|.|<=65536)
    parameter int OUT_W = 16
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 in_valid,
    input  logic [N*N*IN_W-1:0]  a_flat,   // row-major, element (i,k) at (i*N+k)
    input  logic [N*N*IN_W-1:0]  b_flat,   // row-major, element (k,j) at (k*N+j)
    output logic                 out_valid,
    output logic [N*N*OUT_W-1:0] c_flat,   // row-major, element (i,j) at (i*N+j)
    output logic [N*N-1:0]       ovf       // per-element saturation flag
);
    localparam logic signed [ACC_W-1:0] SAT_MAX = 20'sd32767;
    localparam logic signed [ACC_W-1:0] SAT_MIN = -20'sd32768;

    // ---- stage 1: latch operands ----
    logic                v1;
    logic [N*N*IN_W-1:0] a_q, b_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin v1 <= 1'b0; a_q <= '0; b_q <= '0; end
        else begin
            v1 <= in_valid;
            if (in_valid) begin a_q <= a_flat; b_q <= b_flat; end
        end
    end

    // ---- combinational matrix multiply + saturation from latched operands ----
    logic signed [IN_W-1:0]  a2 [0:N-1][0:N-1];
    logic signed [IN_W-1:0]  b2 [0:N-1][0:N-1];
    logic signed [ACC_W-1:0] acc;
    logic signed [OUT_W-1:0] c_comb [0:N-1][0:N-1];
    logic [N*N-1:0]          ov_comb;

    always_comb begin
        // unpack (slice reinterpreted as signed via typed targets)
        for (int i = 0; i < N; i++)
            for (int k = 0; k < N; k++) begin
                a2[i][k] = a_q[(i*N+k)*IN_W +: IN_W];
                b2[i][k] = b_q[(i*N+k)*IN_W +: IN_W];
            end
        ov_comb = '0;
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                acc = '0;
                for (int k = 0; k < N; k++)
                    acc += a2[i][k] * b2[k][j];      // signed MAC
                if (acc > SAT_MAX)      begin c_comb[i][j] = 16'sh7FFF; ov_comb[i*N+j] = 1'b1; end
                else if (acc < SAT_MIN) begin c_comb[i][j] = -16'sh8000; ov_comb[i*N+j] = 1'b1; end
                else                          c_comb[i][j] = acc[OUT_W-1:0];
            end
    end

    // ---- stage 2: register results ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin out_valid <= 1'b0; c_flat <= '0; ovf <= '0; end
        else begin
            out_valid <= v1;
            if (v1) begin
                for (int i = 0; i < N; i++)
                    for (int j = 0; j < N; j++)
                        c_flat[(i*N+j)*OUT_W +: OUT_W] <= c_comb[i][j];
                ovf <= ov_comb;
            end
        end
    end
endmodule
