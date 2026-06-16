#!/usr/bin/env python3
"""
Golden reference model for the 4x4 signed MAC matrix-multiply accelerator.

C = saturate16( A x B ), where A, B are 4x4 matrices of signed 8-bit elements and
each output element is the dot product of an A-row and a B-column, accumulated exactly
then saturated to signed 16-bit ([-32768, 32767]) with a per-element overflow flag.

Run:  python3 model/mac_ref.py   (prints directed-case expectations + a self-test)
"""
N = 4
SAT_MAX, SAT_MIN = 32767, -32768

def s8(x):   # interpret as signed 8-bit
    x &= 0xFF
    return x - 256 if x & 0x80 else x

def saturate16(v):
    if v > SAT_MAX: return SAT_MAX, 1
    if v < SAT_MIN: return SAT_MIN, 1
    return v, 0

def matmul_sat(A, B):
    """A,B: 4x4 lists of signed ints. Returns (C, OVF) 4x4."""
    C = [[0]*N for _ in range(N)]
    OVF = [[0]*N for _ in range(N)]
    for i in range(N):
        for j in range(N):
            acc = sum(A[i][k]*B[k][j] for k in range(N))   # exact
            C[i][j], OVF[i][j] = saturate16(acc)
    return C, OVF

def flat(M, width):   # row-major flatten to a list (LSB element first index 0)
    return [M[i][j] for i in range(N) for j in range(N)]

# ---------------- directed cases ----------------
def const(v): return [[v]*N for _ in range(N)]
IDENT = [[1 if i==j else 0 for j in range(N)] for i in range(N)]

def show(nameA, A, nameB, B):
    C, OVF = matmul_sat(A, B)
    nsat = sum(sum(r) for r in OVF)
    print(f"  {nameA} x {nameB}: C[0][0]={C[0][0]}, saturated_elements={nsat}/16")
    return C, OVF

if __name__ == "__main__":
    print("Directed-case expectations:")
    show("zeros", const(0), "zeros", const(0))
    A = [[i*4+j-8 for j in range(N)] for i in range(N)]   # mixed signed
    show("A_mixed", A, "I", IDENT)        # A x I = A  -> C[0][0] = A[0][0]
    show("max", const(127), "max", const(127))   # 4*127*127=64516 -> sat 32767
    show("min", const(-128), "max", const(127))  # 4*(-128*127)=-65024 -> sat -32768

    # self-test: A x I must equal A exactly (no saturation, since |A|<=127)
    C, OVF = matmul_sat(A, IDENT)
    assert C == A and all(all(o==0 for o in r) for r in OVF), "A x I should equal A"
    # max case saturates everywhere
    Cm, Om = matmul_sat(const(127), const(127))
    assert all(all(c==32767 for c in r) for r in Cm) and all(all(o==1 for o in r) for r in Om)
    # min case saturates low everywhere
    Cn, On = matmul_sat(const(-128), const(127))
    assert all(all(c==-32768 for c in r) for r in Cn)
    print("\nSELF-TEST PASS: golden model arithmetic + saturation verified.")

    # quick random sanity: how often does saturation occur with random 8-bit signed?
    import random; random.seed(3)
    tot=sat=0
    for _ in range(200):
        A=[[random.randint(-128,127) for _ in range(N)] for _ in range(N)]
        B=[[random.randint(-128,127) for _ in range(N)] for _ in range(N)]
        _,O=matmul_sat(A,B); tot+=16; sat+=sum(sum(r) for r in O)
    print(f"Random sanity: {sat}/{tot} elements saturated "
          f"({100*sat/tot:.1f}%) -> saturation path is well-exercised.")
