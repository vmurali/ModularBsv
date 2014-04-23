/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Types::*;
import MemTypes::*;
import Fifo::*;
import RegFile::*;
import FreeList::*;
import Vector::*;

interface NonBlockingCache;
  method Action req(MemReq r);
  method ActionValue#(Tuple2#(Addr, Maybe#(Data))) resp;

  method ActionValue#(MemReq) memReq;
  method Action memResp(Tuple2#(Addr, Data) r);
endinterface

typedef 1024 CacheEntries;
typedef Bit#(TLog#(CacheEntries)) CacheIndex;
typedef Bit#(TSub#(TSub#(AddrSz, TLog#(CacheEntries)), 2)) CacheTag;
typedef 8 NumMshrs;

typedef MemReq MshrEntry;

typedef enum {Free, SendReq} Status deriving (Bits, Eq);

(* synthesize *)
module mkNonBlockingCache(NonBlockingCache);
  RegFile#(CacheIndex, Line) dataArray <- mkRegFileFull;
  RegFile#(CacheIndex, CacheTag) tagArray <- mkRegFileFull;
  RegFile#(CacheIndex, Bool) dirtyArray <- mkRegFileFull;
  RegFile#(CacheIndex, Bool) validArray <- mkRegFileFull;
  Vector#(NumMshrs, Reg#(MshrEntry)) mshr <- replicateM(mkRegU);
  Vector#(NumMshrs, Reg#(Bool)) mshrValid <- replicateM(mkReg(False));

  Reg#(Status) status <- mkReg(Free);

  FreeList#(NumMshrs) fl <- mkFreeList;
  Reg#(Bitt#(NumMshrs)) flIdx <- mkRegU;

  Reg#(Bit#(TLog#(TAdd#(CacheEntries, 1)))) init <- mkReg(0);

  Fifo#(2, MemReq) inQ <- mkCFFifo;
  Fifo#(2, Tuple2#(Addr, Maybe#(Data))) outQ <- mkCFFifo;

  Fifo#(2, MemReq) memReqQ <- mkCFFifo;
  Fifo#(2, Tuple2#(Addr, Data)) memRespQ <- mkCFFifo;

  function CacheIndex getIdx(Addr addr) = truncate(addr >> 2);
  function CacheTag getTag(Addr addr) = truncateLSB(addr);

  let inited = truncateLSB(init) == 1'b1;

  rule handleReq(status == Free && inited);
    let r = inQ.first;
    Bool already = False;
    for(Integer i = 0; i < valueOf(NumMshrs); i = i + 1)
      if(mshrValid[i] && mshr[i].addr == r.addr)
        already = True;
    if(!already)
    begin
      let r = inQ.first;
      let ridx = getIdx(r.addr);
      let rtag = getTag(r.addr);
      let currData = dataArray.sub(ridx);
      let currTag = tagArray.sub(ridx);
      if(tagArray.sub(ridx) == rtag && validArray.sub(ridx))
      begin
        inQ.deq;
        $display("Cache hit: %x %d", r.addr, r.op);
        if(r.op == St)
        begin
          dataArray.upd(ridx, r.data);
          outQ.enq(tuple2(r.addr, Invalid));
        end
        else
          outQ.enq(tuple2(r.addr, Valid (currData)));
      end
      else
      begin
        let currAddr = {currTag, ridx, 2'b0};
        if(validArray.sub(ridx) && dirtyArray.sub(ridx))
        begin
          $display("Cache Wb: %x %x", currAddr, currData);
          memReqQ.enq(MemReq{op: St, data: currData, addr: currAddr});
        end
        status <= SendReq;
        let _flIdx <- fl.alloc;
        flIdx <= _flIdx;
        mshrValid[flIdx] <= False;
      end
    end
  endrule

  rule handleReq2(status == SendReq && inited);
    let r = inQ.first;
    $display("Cache Miss: %x %d %d", r.addr, r.op, flIdx);
    let ridx = getIdx(r.addr);
    validArray.upd(ridx, True);
    dirtyArray.upd(ridx, False);
    tagArray.upd(ridx, getTag(r.addr));
    memReqQ.enq(MemReq{op: Ld, data: ?, addr: r.addr});
    mshr[flIdx] <= r;
    mshrValid[flIdx] <= True;
    inQ.deq;
    status <= Free;
  endrule

  (* preempts = "handleResp, (handleReq2, handleReq)" *)
  rule handleResp(inited);
    match {.addr, .data} = memRespQ.first;
    MemReq r = ?;
    Bitt#(NumMshrs) idx = ?;
    for(Integer i = 0; i < valueOf(NumMshrs); i = i + 1)
    begin
      let _r = mshr[i];
      if(mshrValid[i] && _r.addr == addr)
      begin
        r = _r;
        idx = fromInteger(i);
        mshrValid[i] <= False;
      end
    end
    $display("Cache Fill: %x %x %d %d", addr, data, r.op, idx);
    fl.free(idx);
    if(r.op == St)
    begin
      dataArray.upd(getIdx(addr), r.data);
      outQ.enq(tuple2(addr, Invalid));
      dirtyArray.upd(getIdx(addr), True);
    end
    else
    begin
      dataArray.upd(getIdx(addr), data);
      outQ.enq(tuple2(addr, Valid (data)));
    end
    memRespQ.deq;
  endrule

  rule initialize(!inited);
    init <= init + 1;
    validArray.upd(truncate(init), False);
    dirtyArray.upd(truncate(init), False);
  endrule

  method Action req(MemReq r) if(inited && fl.init);
    inQ.enq(r);
  endmethod

  method ActionValue#(Tuple2#(Addr, Maybe#(Data))) resp;
    outQ.deq;
    return outQ.first;
  endmethod

  method ActionValue#(MemReq) memReq;
    memReqQ.deq;
    return memReqQ.first;
  endmethod

  method Action memResp(Tuple2#(Addr, Data) r);
    memRespQ.enq(r);
  endmethod
endmodule
