import FIFOF::*;

typedef Bit#(TLog#(n)) Bitt#(type n);

interface FreeList#(numeric type t);
  method Bool init;
  method Bool isAvail;
  method ActionValue#(Bitt#(t)) alloc;
  method Action free(Bitt#(t) x);
endinterface

module mkFreeList(FreeList#(t));
  FIFOF#(Bitt#(t)) f <- mkSizedFIFOF(valueOf(t));

  Reg#(Bitt#(t)) initVal <- mkReg(0);
  Reg#(Bool) inited <- mkReg(False);

  rule initRl(!inited);
    initVal <= initVal + 1;
    f.enq(initVal);
    if(initVal == maxBound)
      inited <= True;
  endrule

  method Bool init = inited;

  method Bool isAvail if(inited) = f.notEmpty;

  method ActionValue#(Bitt#(t)) alloc if(inited && f.notEmpty);
    f.deq;
    return f.first;
  endmethod

  method Action free(Bitt#(t) x) if(inited);
    f.enq(x);
  endmethod
endmodule
