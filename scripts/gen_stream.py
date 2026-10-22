"""Generate signed matrix products independently using Python integers."""
from pathlib import Path
import random

def pack(values, width):
    return sum((v & ((1 << width)-1)) << (width*i) for i,v in enumerate(values))

def generate(n=4, width=16):
    rng=random.Random(20261022)
    rows=[]
    for t in range(400):
        reset = t in (0,1,157,158)
        valid = (t % 7 != 0) and t < 398
        if t<10:
            av,bv=[(0,0),(127,127),(-128,-128),(-128,127),(1,-1)][t%5]
            a=[av]*(n*n); b=[bv]*(n*n)
        else:
            a=[rng.randrange(-128,128) for _ in range(n*n)]
            b=[rng.randrange(-128,128) for _ in range(n*n)]
        c=[]; ov=[]
        lo=-(1 << (width-1)); hi=(1 << (width-1))-1
        for i in range(n):
            for j in range(n):
                x=sum(a[i*n+k]*b[k*n+j] for k in range(n))
                c.append(min(hi,max(lo,x))); ov.append(int(x<lo or x>hi))
        rows.append((int(not reset),int(valid),pack(a,8),pack(b,8),pack(c,width),pack(ov,1)))
    Path('build').mkdir(exist_ok=True)
    Path('build/stream.txt').write_text('\n'.join(' '.join(f'{v:x}' for v in r) for r in rows)+'\n')
    print(f'Python oracle: {len(rows)} cycles, N={n}, OUT_W={width}, seed=20261022')

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(); p.add_argument('--n',type=int,default=4); p.add_argument('--width',type=int,default=16)
    args=p.parse_args(); generate(args.n,args.width)
