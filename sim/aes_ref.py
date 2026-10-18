# Independent AES-128 reference: round keys and per-round states for the same vector
sb=[0]*256
p=q=1
while True:
    p=p^((p<<1)&0xff)^(0x1b if p&0x80 else 0)
    q^=q<<1; q^=q<<2; q^=q<<4; q&=0xff
    if q&0x80: q^=0x09
    x=q^((q<<1|q>>7)&0xff)^((q<<2|q>>6)&0xff)^((q<<3|q>>5)&0xff)^((q<<4|q>>4)&0xff)
    sb[p]=x^0x63
    if p==1: break
sb[0]=0x63
key=bytes.fromhex('000102030405060708090a0b0c0d0e0f'); pt=bytes.fromhex('00112233445566778899aabbccddeeff')
w=[list(key[4*i:4*i+4]) for i in range(4)]; rc=1
for i in range(4,44):
    t=w[i-1][:]
    if i%4==0:
        t=t[1:]+t[:1]; t=[sb[b] for b in t]; t[0]^=rc; rc=((rc<<1)^0x11b)&0xff if rc&0x80 else rc<<1
    w.append([a^b for a,b in zip(w[i-4],t)])
rk=[bytes(sum(w[4*r:4*r+4],[])) for r in range(11)]
def xt(a): return ((a<<1)^0x1b)&0xff if a&0x80 else a<<1
def mix(c): a=c; return [xt(a[0])^xt(a[1])^a[1]^a[2]^a[3], a[0]^xt(a[1])^xt(a[2])^a[2]^a[3], a[0]^a[1]^xt(a[2])^xt(a[3])^a[3], xt(a[0])^a[0]^a[1]^a[2]^xt(a[3])]
def rnd(s,k,last):
    s=[sb[b] for b in s]
    s=[s[(4*((c+r)%4))+r] for c in range(4) for r in range(4)]
    if not last: s=sum([mix(s[4*c:4*c+4]) for c in range(4)],[])
    return [a^b for a,b in zip(s,k)]
s=[a^b for a,b in zip(pt,rk[0])]
print("RK0  "+rk[0].hex()); st=[bytes(s).hex()]
for r in range(1,11):
    s=rnd(s,rk[r],r==10); st.append(bytes(s).hex()); print(f"RK{r:<2} "+rk[r].hex())
print("S0   "+st[0]); print("S1   "+st[1]); print("S2   "+st[2]); print("S3   "+st[3]); print("S9   "+st[9]); print("OUT  "+st[10])
