/*

Copyright (C) 2012

Arvind <arvind@csail.mit.edu>
Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

import Ehr::*;
import ProcTypes::*;
import Proc::*;
import Types::*;

typedef enum {Start, Run} State deriving (Bits, Eq);

(* synthesize *)
module mkTestBench();
  (* doc = "cycle._read() " *)
  Proc proc <- mkProc;

  Reg#(Bit#(32)) cycle <- mkReg(0);
  Reg#(State)    state <- mkReg(Start);

  rule start(state == Start);
    proc.hostToCpu(32'h1000);
    state <= Run;
  endrule

  rule countCycle(state == Run);
    cycle <= cycle + 1;
    $display("\ncycle %d", cycle);
  endrule

  rule run(state == Run);
    match {.idx, .data} <- proc.cpuToHost;
    if(idx == 18)
      $fwrite(stderr, "%d", data);
    else if(idx == 19)
      $fwrite(stderr, "%c", data);
    else if(idx == 21)
    begin
      if(data == 0)
        $fwrite(stderr, "PASSED\n");
      else
        $fwrite(stderr, "FAILED %d\n", data);
      $finish;
    end
  endrule
endmodule

