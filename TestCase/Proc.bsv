/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

import Ehr::*;
/*
The simulated machine:
ISA: SMIPS with two co-processor registers (10, 21) for obtaining the stats and results of test programs. For more details, see Cop module

6-stage in-order pipeline:
    Fetch(F) , Decode(D), RegRead(R), Execute(E), Memory(M), Writeback(W)

Branch prediction scheme:
    PcPred in F, DirPred in D. PcPred and DirPred can be changed in a modular fashion. However, making them parameters will complicate the hardware for the simple case (pc+4).
    There's an epoch register in each of D and E. F contains a shadow of each of these epoch registers and sends the shadow register values with each instruction. D also contains a shadow of eEpoch.
    F updates its shadow epoch registers on getting a redirect from either D or E, E gets priority and D can redirect F only if the incoming eEpoch in D's redirect matches F's eEpoch.
    E marks the incoming instruction as poisoned if the incoming eEpoch doesn't match its local epoch. It updates its local epoch on a misprediction.
    At the D stage, if the incoming eEpoch is different from its shadow (deEpoch), then both deEpoch and dEpoch are updated with the incoming epochs. D drops the incoming instruction only when the incoming eEpoch matches deEpoch, but the incoming dEpoch doesn't match the local dEpoch. Finally, D changes dEpoch on wrong prediction.

Hazard detection:
    Uses a scoreboard which keeps track of destination register for each instruction beyond R stage.
    WAW hazards cause stalls.
    Bypass network from E, M, W to R. It reduces the number of stalls due to RAW hazards

Caches:
    I-cache and D-cache.
    Cache module is parameterized:
      Combinational hits, can be changed to any number of cycles.
      Blocks on a miss, can be changed to non-blocking cache.

General comment about Fifos:
The design uses 3 types of Fifos: ConflictFree (CF), Pipeline and Bypass. With rare exceptions, any Pipeline and Bypsas Fifo can be changed to CF Fifos without affecting the correctness, with potential performance penalty. Replacing a CF Fifo by a Pipeline or Bypass Fifo usually creates performance gains but can cause combinational cycles and conflicts between rules when not done properly. Since the performance differences are significant, a performance study should document the type of each Fifo in use.
This machine uses (2 element) CF Fifos in the forward direction, and bypsas Fifos in the reverse direction. All of the CF Fifos can be replaced by Pipeline Fifos to reduce the buffers but it may not gain any performance.
*/

// Imports definitions (of types, interfaces, modules, functions, etc) from the following files
import Types::*;
import ProcTypes::*;
import MemTypes::*;
import RFile::*;
import Memory::*;
import Decode::*;
import Exec::*;
import Cop::*;
import Fifo::*;
import Scoreboard::*;
import AddrPred::*;
import DirPred::*;
import Cache::*;
import Connectable::*;
import Vector::*;

// Defines the (struct) type of the message between each stage
typedef struct {
  Addr pc;
  Addr ppc;
  Bool dEpoch;
  Bool eEpoch;
  Data inst;
} Fetch2Decode deriving (Bits, Eq);

typedef struct {
  Addr pc;
  Addr ppc;
  Bool epoch;
  DecodedInst dInst;
} Decode2RegRead deriving (Bits, Eq);

typedef struct {
  Addr pc;
  Addr ppc;
  Bool epoch;
  DecodedInst dInst;
  Data rVal1;
  Data rVal2;
  Data copVal;
} RegRead2Exec deriving (Bits, Eq);

typedef struct {
  Bool poisoned;
  IType iType;
  Maybe#(FullIndx) dst;
  Data data;
  Addr addr;
} Exec2Mem deriving (Bits, Eq);

typedef struct {
  Bool poisoned;
  Maybe#(FullIndx) dst;
  Data data;
} Mem2Wb deriving (Bits, Eq);

(* synthesize *)
module mkSb(Scoreboard#(16));
  (* doc = "[hello.hello]"*)
  let fp1 <- empty_fp;
  let fp2 <- empty_fp;
  Scoreboard#(16) sb <- mkCFScoreboard;
  return sb;
endmodule

interface MkProcFp;
  method Action t1(Bool x);
  method Bit#(32) t2(Bool x, Bit#(32) y);
  method ActionValue#(Bit#(32)) t3(Bit#(3) y, Bool x);
  method Bit#(31) t4;
endinterface

// Defines the Processor module, with a synthesis boundary, ie a verilog file is created for this module
import "BVI"
module mkProc_fp(MkProcFp);
  method t1(t11) enable (t1_en) ready (t1_rdy);
  method t2_ret t2(t21, t22) ready (t2_rdy);
  method t3_ret t3(t31, t32) enable(t3_en) ready (t3_rdy);
  method t4_ret t4 ready (t4_rdy);
  schedule t1 CF t1;
  schedule t1 CF t2;
  schedule t1 CF t3;
  schedule t1 CF t4;
  schedule t2 CF t1;
  schedule t2 C t2;
  schedule t2 SB t3;
  schedule t2 SB t4;
  schedule t3 CF t1;
  //schedule t3 SA t2;
  schedule t3 C t3;
  schedule t3 C t4;
  schedule t4 CF t4;
endmodule


(* synthesize *)
module mkProc(Proc);

  //Instantiating all the state elements of the processor.

  (* doc = "[this.r1 this.r2] [this.b1] [rf.rd1 rf.rd2]"*)
  let fp1 <- mkProc_fp;
  let fp2 <- mkProc_fp;
  let sb <- mkSb;

  // Architectural State
  (* doc = "rf.rd2 rf.rd1" *)
  Reg#(Addr) pc <- mkRegU;
  RFile      rf <- mkRFile;
  Memory    mem <- mkMemory;
  Cop       cop <- mkCop;

  // Microarchitectural State
  Fifo#(2, Fetch2Decode)    f2d <- mkCFFifo;
  Fifo#(2, Decode2RegRead) d2rf <- mkCFFifo;
  Fifo#(2, RegRead2Exec)  rf2ex <- mkCFFifo;
  Fifo#(2, Exec2Mem)       ex2m <- mkCFFifo;
  Fifo#(2, Mem2Wb)         m2wb <- mkCFFifo;

  // Microarchitectural state associated with control hazards
  AddrPred  pcPred <- mkBtb;
  DirPred  dirPred <- mkCounterPred2Bit;

  Fifo#(1, Redirect) ex2fRedirect <- mkBypassFifo;
  Fifo#(1, Redirect) ex2dRedirect <- mkBypassFifo;

  Fifo#(1, Tuple2#(Bool, Addr)) dirPredRedirect <- mkBypassFifo;

  Reg#(Bool) feEpoch <- mkReg(False);
  Reg#(Bool) fdEpoch <- mkReg(False);
  Reg#(Bool) deEpoch <- mkReg(False);
  Reg#(Bool)  dEpoch <- mkReg(False);
  Reg#(Bool)  eEpoch <- mkReg(False);

  // Microarchitectural state associated with data hazards

  Fifo#(1, Tuple2#(Maybe#(FullIndx), Data)) bypassFromExec <- mkBypassFifo;
  Fifo#(1, Tuple2#(Maybe#(FullIndx), Data))  bypassFromMem <- mkBypassFifo;
  Fifo#(1, Tuple2#(Maybe#(FullIndx), Data))   bypassFromWb <- mkBypassFifo;

  // Cache states
  Cache iCache <- mkCache;
  Cache dCache <- mkCache;

  Fifo#(1, Tuple4#(Addr, Addr, Bool, Bool)) f12f2 <- mkBypassFifo;
  Fifo#(1, Exec2Mem) m12m2 <- mkBypassFifo;

  // The following functions encapsulate some common idioms used in all the designs.

  // handleFetchRedirect function handles the effect of redirects from E and D at F.
  // handleDecodeRedirect function handles the effect of redirects from E at D.

  function ActionValue#(Tuple2#(Bool, Addr)) handleFetchRedirect(Fifo#(1, Redirect) ex2fRedrct, Fifo#(1, Tuple2#(Bool, Addr)) dirPredRedrct);
  actionvalue
    Bool redirected;
    Addr updatedPc;
    // Dequeue the incoming redirect and update the predictor whether it's a mispredict or not
    if(ex2fRedrct.notEmpty)
    begin
      pcPred.update(ex2fRedrct.first);
      ex2fRedrct.deq;
    end
    // If the direction predictor has a redirect, deq it
    if(dirPredRedrct.notEmpty)
      dirPredRedrct.deq;
    // change pc and the fetch's copy of the eEpoch only on a mispredict
    if(ex2fRedrct.notEmpty && ex2fRedrct.first.mispredict)
    begin
      redirected = True;
      updatedPc = ex2fRedrct.first.nextPc;
      feEpoch <= !feEpoch;
    end
    // Check if the direction preditor redirect has the same execute epoch. Change the pc and fetch's copy of the dEpoch only if that is true.
    else if(dirPredRedrct.notEmpty && tpl_1(dirPredRedrct.first) == feEpoch)
    begin
      redirected = True;
      updatedPc = tpl_2(dirPredRedrct.first);
      fdEpoch <= !fdEpoch;
    end
    // fetch the new instruction on a non mispredict
    else
    begin
      redirected = False;
      updatedPc = pcPred.predPc(pc);
    end
    return tuple2(redirected, updatedPc);
  endactionvalue
  endfunction

  function ActionValue#(Maybe#(Addr)) handleDecodeRedirect(Fifo#(1, Redirect) ex2dRedrct, Fifo#(1, Tuple2#(Bool, Addr)) dirPredRedrct, DecodedInst dInst, Addr pcVal, Addr ppc, Bool fdEpochVal, Bool feEpochVal);
  actionvalue
    Maybe#(Addr) ret;

    let dEpochLocal = dEpoch;

    if(ex2dRedrct.notEmpty)
    begin
      dirPred.update(ex2dRedrct.first);
      ex2dRedrct.deq;
    end

    // Copy both the incoming epochs if the incoming execute epoch is different from the local copy
    if(feEpoch != deEpoch)
    begin
      deEpoch <= feEpochVal;
      dEpochLocal = fdEpochVal;
    end
    // After potential change to the local epochs, check if the incoming decode epoch is the same as the local decode epoch. Proceed only if true
    if(fdEpochVal == dEpochLocal)
    begin
      let nextAddr = dInst.iType == Jr? ppc : brAddrCalc(pcVal, ?, dInst.iType, validValue(dInst.imm), dirPred.predDir(pcVal));
      ret = Valid (nextAddr);
      if(nextAddr != ppc)
      begin
        dirPredRedrct.enq(tuple2(feEpochVal, nextAddr));
        dEpochLocal = !dEpochLocal;
      end
    end
    else
      ret = Invalid;
    // Put back the changes to the local decode epoch into the register
    dEpoch <= dEpochLocal;
    return ret;
  endactionvalue
  endfunction

  // isRawH returns if the incoming instruction has a RAW hazard with an instruction already in flight. It checks the bypass network, and returns no RAW hazard if the value is present in the bypass network
  function Bool isRawH(Maybe#(FullIndx) src, function Bool search(Maybe#(FullIndx) r),
                       Fifo#(1, Tuple2#(Maybe#(FullIndx), Data)) bExec, Fifo#(1, Tuple2#(Maybe#(FullIndx), Data)) bMem, Fifo#(1, Tuple2#(Maybe#(FullIndx), Data)) bWb);
    Bool ret;
    if(search(src))
    begin
      if(bExec.notEmpty && tpl_1(bExec.first) == src)
        ret = False;
      else if(bMem.notEmpty && tpl_1(bMem.first) == src)
        ret = False;
      else if(bWb.notEmpty && tpl_1(bWb.first) == src)
        ret = False;
      else
        ret = True;
    end
    else
      ret = False;
    return ret;
  endfunction

  // regRead gets the value of the register either by reading the bypass network or the register file (in that order).
  function Data regRead(Maybe#(FullIndx) src, function Data read(RIndx x),
                        Fifo#(1, Tuple2#(Maybe#(FullIndx), Data)) bExec, Fifo#(1, Tuple2#(Maybe#(FullIndx), Data)) bMem, Fifo#(1, Tuple2#(Maybe#(FullIndx), Data)) bWb);
    Data ret;
    if(bExec.notEmpty && tpl_1(bExec.first) == src)
      ret = tpl_2(bExec.first);
    else if(bMem.notEmpty && tpl_1(bMem.first) == src)
      ret = tpl_2(bMem.first);
    else if(bWb.notEmpty && tpl_1(bWb.first) == src)
      ret = tpl_2(bWb.first);
    else
      ret = read(validRegValue(src));
    return ret;
  endfunction

  // These rules describe each of the stages of the processor. Every stage not involving memory accesses has one rule, while the ones with memory accesses are split into req-resp rules.

  // The two rules are connected by a bypass Fifo, though any Fifo can be used, which may make it a separate stage
  rule doFetch1(cop.started);
    match {.redirected, .updatedPc} <- handleFetchRedirect(ex2fRedirect, dirPredRedirect);
    pc <= updatedPc;
    if(!redirected)
    begin
      iCache.req(MemReq{op: Ld, addr: pc, data: ?});
      f12f2.enq(tuple4(pc, updatedPc, fdEpoch, feEpoch));
    end
  endrule

  rule doFetch2(cop.started);
    let inst <- iCache.resp;
    match {.pc, .ppc, .fdEpoch, .feEpoch} = f12f2.first;
    f12f2.deq;
    f2d.enq(Fetch2Decode{pc: pc, ppc: ppc, eEpoch: feEpoch, dEpoch: fdEpoch, inst: inst});

    $display("Fetch: pc: %h dEpoch: %d eEpoch: %d inst: (%h) expanded: ", pc, fdEpoch, feEpoch, inst, showInst(inst));
  endrule

  rule doDecode;
    let pc = f2d.first.pc;
    let ppc = f2d.first.ppc;
    let fdEpoch = f2d.first.dEpoch;
    let feEpoch = f2d.first.eEpoch;
    let inst = f2d.first.inst;

    let dInst = decode(inst);
    let nextAddr <- handleDecodeRedirect(ex2dRedirect, dirPredRedirect, dInst, pc, ppc, fdEpoch, feEpoch);

    fp2.t1(True);
    if(isValid(nextAddr))
    begin
      d2rf.enq(Decode2RegRead{pc: pc, ppc: validValue(nextAddr), epoch: feEpoch, dInst: dInst});
      $display("Decode: pc: %h dEpoch: %d eEpoch: %d", pc, fdEpoch, feEpoch);
    end
    f2d.deq;
  endrule

  rule doRegRead;
    let pc = d2rf.first.pc;
    let ppc = d2rf.first.ppc;
    let epoch = d2rf.first.epoch;
    let dInst = d2rf.first.dInst;

    let waw = False;

    waw = sb.search3(pc == 0? dInst.dst : unpack (~ pack (dInst.dst)));
/*
    if(pc == 0)
      waw = sb.search3(dInst.dst);
    else
      waw = sb.search3(unpack(~pack(dInst.dst)));
*/
    let raw = isRawH(dInst.src1, sb.search1, bypassFromExec, bypassFromMem, bypassFromWb) || isRawH(dInst.src2, sb.search2, bypassFromExec, bypassFromMem, bypassFromWb);

    if(bypassFromExec.notEmpty)
      bypassFromExec.deq;
    if(bypassFromMem.notEmpty)
      bypassFromMem.deq;
    if(bypassFromWb.notEmpty)
      bypassFromWb.deq;

    if(!waw && !raw)
    begin
      Data rVal1 = regRead(dInst.src1, rf.rd1, bypassFromExec, bypassFromMem, bypassFromWb);
      Data rVal2 = regRead(dInst.src2, rf.rd2, bypassFromExec, bypassFromMem, bypassFromWb);
      Data copVal = regRead(dInst.src1, cop.rd, bypassFromExec, bypassFromMem, bypassFromWb);

      rf2ex.enq(RegRead2Exec{pc: pc, ppc: ppc, dInst: dInst, epoch: epoch, rVal1: rVal1, rVal2: rVal2, copVal: copVal});
      sb.insert(dInst.dst);
      d2rf.deq;

      $display("RegRead: pc: %h", pc);
    end
  endrule

  rule doExec;
    let dInst  = rf2ex.first.dInst;
    let pc     = rf2ex.first.pc;
    let ppc    = rf2ex.first.ppc;
    let epoch  = rf2ex.first.epoch;
    let rVal1  = rf2ex.first.rVal1;
    let rVal2  = rf2ex.first.rVal2;
    let copVal = rf2ex.first.copVal;

    // mark the incoming instruction as poisoned if the epcohs dont match. The instruction is passed down to the W stage to remove the entries from the scoreboard
    let poisoned = epoch != eEpoch;
    let eInst = exec(dInst, rVal1, rVal2, pc, ppc, copVal);
    if(!poisoned)
    begin
      // If an unsupported instruction is encountered, flag an error and exit simulation
      if(eInst.iType == Unsupported)
      begin
        $fwrite(stderr, "Executing unsupported instruction at pc: %x. Exiting\n", pc);
        $finish;
      end

      // On any branch, the actual direction of the branch is passed on to both F and D to update their respective predictors
      if(eInst.iType == J || eInst.iType == Jr || eInst.iType == Br)
      begin
        let redirect = Redirect{pc: pc, nextPc: eInst.addr, brType: eInst.iType, taken: eInst.brTaken, mispredict: eInst.mispredict};
        ex2fRedirect.enq(redirect);
        ex2dRedirect.enq(redirect);
      end

      // On a mispredict, the epoch is changed
      if(eInst.mispredict)
        eEpoch <= !eEpoch;

      // If it's not a load instruction, send the value to bypass network
      if(eInst.iType != Ld)
        bypassFromExec.enq(tuple2(eInst.dst, eInst.data));

      $display("Execute: pc: %h epoch: %d", pc, epoch);
    end
    ex2m.enq(Exec2Mem{poisoned: poisoned, iType: eInst.iType, dst: eInst.dst, data: eInst.data, addr: eInst.addr});
    rf2ex.deq;
  endrule

  // Memory rule is split similar to the fetch rule
  rule doMem1;
    let poisoned = ex2m.first.poisoned;
    let iType = ex2m.first.iType;
    let dst = ex2m.first.dst;
    let data = ex2m.first.data;
    let addr = ex2m.first.addr;

    // Do any update to memory (and bypsas network) only when the instruction is not poisoned
    if(!poisoned)
    begin
      if(iType == Ld)
        dCache.req(MemReq{op: Ld, addr: addr, data: ?});
      else if(iType == St)
      begin
        dCache.req(MemReq{op: St, addr: addr, data: data});
      end
    end

    if(pc == 0)
      sb.insert(tagged Invalid);
    else if (pc == 1)
      sb.insert(tagged Valid FullIndx{regType: Normal, idx: 16});
    else if (pc == 4)
      sb.insert(tagged Valid FullIndx{regType: CopReg, idx: 23});

    m12m2.enq(ex2m.first);
    ex2m.deq;
  endrule

  rule doMem2;
    let poisoned = m12m2.first.poisoned;
    let iType = m12m2.first.iType;
    let dst = m12m2.first.dst;
    let data = m12m2.first.data;
    let addr = m12m2.first.addr;

    if(!poisoned)
    begin
      if(iType == Ld)
      begin
        data <- dCache.resp;
      end
      bypassFromMem.enq(tuple2(dst, data));
    end

    m2wb.enq(Mem2Wb{poisoned: poisoned, dst: dst, data: data});
    m12m2.deq;
  endrule

  rule doWb;
    let poisoned = m2wb.first.poisoned;
    let dst = m2wb.first.dst;
    let data = m2wb.first.data;

    // Do any update to register file (and bypsas network) only when the instruction is not poisoned
    if(!poisoned)
    begin
      if(isValid(dst) && validValue(dst).regType == Normal)
        rf.wr(validRegValue(dst), data);
      cop.wr(dst, data);

      bypassFromWb.enq(tuple2(dst, data));
    end

    sb.remove;
    m2wb.deq;
  endrule

  mkConnection(mem.iReq, iCache.memReq);
  mkConnection(mem.iResp, iCache.memResp);
  mkConnection(mem.dReq, dCache.memReq);
  mkConnection(mem.dResp, dCache.memResp);

  method ActionValue#(Tuple2#(RIndx, Data)) cpuToHost;
    let ret <- cop.cpuToHost;
    return ret;
  endmethod

  method Action hostToCpu(Bit#(32) startpc) if (!cop.started);
    cop.start;
    pc <= startpc;
  endmethod
endmodule
