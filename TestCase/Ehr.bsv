/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

typedef  Vector#(n, Reg#(t)) Ehr#(numeric type n, type t);

module empty_fp(Empty);
endmodule

interface EHR#(type t);
  method t r0;
  method t r1;
  method t r2;
  method t r3;
  method Action w0(t x);
  method Action w1(t x);
  method Action w2(t x);
  method Action w3(t x);
endinterface

import "BVI"
module mkEHR#(t init)(EHR#(t)) provisos(Bits#(t, a__));
  parameter width = valueOf(a__);
  parameter init = pack(init);
  method r0 r0;
  method r1 r1;
  method r2 r2;
  method r3 r3;
  method w0(w0) enable(w0en);
  method w1(w1) enable(w1en);
  method w2(w2) enable(w2en);
  method w3(w3) enable(w3en);

  schedule r0 SB (w0, r1, w1, r2, w2, r3, w3);
  schedule r1 SB (w1, r2, w2, r3, w3);
  schedule r2 SB (w2, r3, w3);
  schedule r3 SB (w3);
  schedule w0 SB (r1, w1, r2, w2, r3, w3);
  schedule w1 SB (r2, w2, r3, w3);
  schedule w2 SB (r3, w3);
  schedule r0 CF r0;
  schedule r1 CF r1;
  schedule r2 CF r2;
  schedule r3 CF r3;
  schedule w0 C w0;
  schedule w1 C w1;
  schedule w2 C w2;
  schedule w3 C w3;
endmodule

import Vector::*;

module mkEhr#(t init)(Ehr#(n, t)) provisos(Bits#(t, tSz));
  Ehr#(n, t) r = newVector;
  EHR#(t) e <- mkEHR(init);

  if(valueOf(n) > 0)
  r[0] = (interface Reg;
            method _write = e.w0;
            method _read = e.r0;
          endinterface);
  if(valueOf(n) > 1)
  r[1] = (interface Reg;
            method _write = e.w1;
            method _read = e.r1;
          endinterface);
  if(valueOf(n) > 2)
  r[2] = (interface Reg;
            method _write = e.w2;
            method _read = e.r2;
          endinterface);
  if(valueOf(n) > 3)
  r[3] = (interface Reg;
            method _write = e.w3;
            method _read = e.r3;
          endinterface);
  for(Integer i = 4; i < valueOf(n); i=i+1)
  r[i] = (interface Reg;
            method _write(x) = noAction;
            method _read = ?;
          endinterface);
  return r;
endmodule

module mkReg#(t init)(Reg#(t)) provisos(Bits#(t, tSz));
  EHR#(t) e <- mkEHR(init);
  method _read = e.r0;
  method _write = e.w0;
endmodule

module mkRegU(Reg#(t)) provisos(Bits#(t, tSz));
  EHR#(t) e <- mkEHR(unpack(0));
  method _read = e.r0;
  method _write = e.w0;
endmodule

interface RegFile#(type idx, type t);
  method t sub(idx i);
  method Action upd(idx i, t v);
endinterface

import "BVI"
module mkRegFile#(String init)(RegFile#(idx, t)) provisos(Bits#(t, tSz), Bits#(idx, sz));
  parameter width = valueOf(tSz);
  parameter init = init;
  parameter size = 1<<valueOf(sz);
  method sub0 sub(sub1);
  method upd(upd0, upd1) enable(upden);

  schedule sub C sub;
  schedule sub SB upd;
  schedule upd C upd;
endmodule
