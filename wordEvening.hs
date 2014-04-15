Module: mkTestBench

Instances: 
[{
   instName: proc
   moduleName: mkProc
   args : [names] // doc for instance (keyword :AP inst 
}] 

Bindings:
[ (bindName, size, expression) ]

Rule:
[ {
    ruleName,
    ruleGuard,
    ruleBody } ]

ruleBody = [ (Maybe bindName, calledMethod, [calledMethodArg]) ]

Method:
[ {methodName,
   methodGuard,
   methodResult,
   methodBody } ]

methodBody = [ (Maybe bindname, calledMethod, [calledMethodArg])]

FormalParameters = //instance for fp 
 [
	methodName,
	(Value|Value0|Action|ActionValue),
	Maybe ReturnSize,
	[ArgumentSize]
 ]

PriorityList= //DOC for fp
 [ [Name] | Name ]



AP local

AP rules

AP Scheduling Pragmas

AP interface

AP apkg_interface def module
[AIAction
AIDef]

--AP instance comments


=== ATS:
APackage mkTestBench
-- APackage parameters
[]
-- APackage arguments
clock { osc = CLK }
reset { RST_N }
-- APackage wire info
clock info  clock default_clock(CLK, {-inhigh-});
reset info  reset default_reset(RST_N) clocked_by(default_clock);
arg info  [clockarg default_clock;, resetarg default_reset;]
-- APackage clock domains
[(0, [{ osc:  CLK gate:  1'd1 }])]
-- APackage resets
[(0, { wire:  RST_N })]
-- AP state elements
proc :: ABSTRACT:  Proc.Proc­ = mkProc
				(VModInfo
				 mkProc
				 clock default_clock(CLK, {-inhigh-});
				 reset default_reset(RST_N) clocked_by(default_clock);
				 [clockarg default_clock;, resetarg default_reset;]
				 [method (cpuToHost, [])cpuToHost enable ((EN_cpuToHost,
									   [])) clocked_by (default_clock) reset_by (default_reset);,
				  method (RDY_cpuToHost,
					  [reg])RDY_cpuToHost clocked_by (default_clock) reset_by (default_reset);,
				  method hostToCpu((hostToCpu_startpc, [])) enable ((EN_hostToCpu,
										     [])) clocked_by (default_clock) reset_by (default_reset);,
				  method (RDY_hostToCpu,
					  [])RDY_hostToCpu clocked_by (default_clock) reset_by (default_reset);]
				 SchedInfo
				 [RDY_cpuToHost CF [RDY_cpuToHost, RDY_hostToCpu, cpuToHost, hostToCpu],
				  RDY_hostToCpu CF [RDY_hostToCpu, cpuToHost, hostToCpu],
				  cpuToHost CF hostToCpu,
				  hostToCpu SBR hostToCpu,
				  cpuToHost C cpuToHost]
				 []
				 []
				 []
				 [])
				[clock { osc:  CLK gate:  1'd1 }, reset { wire:  RST_N }]
				[]
				meth types=[([], Just (Bit 1), Just (Bit 37)),
					    ([], Nothing, Just (Bit 1)),
					    ([Bit 32], Just (Bit 1), Nothing),
					    ([], Nothing, Just (Bit 1))]
				port types=cpuToHost -> Prelude.PrimPair (Prelude.Bit 5) (Prelude.Bit 32)
					   hostToCpu_startpc -> Prelude.Bit 32
cycle :: ABSTRACT:  Prelude.VReg = RegN
				   (VModInfo
				    RegN
				    clock _clk__1(CLK, {-unused-});
				    reset _rst__1(RST) clocked_by(_clk__1);
				    [clockarg _clk__1;, resetarg _rst__1;, param width;, param init;]
				    [method (Q_OUT, [reg])read clocked_by (_clk__1) reset_by (_rst__1);,
				     method write((D_IN, [reg])) enable ((EN,
									  [])) clocked_by (_clk__1) reset_by (_rst__1);]
				    SchedInfo [read CF read, read SB write, write SBR write] [] [] []
				    [])
				   [clock { osc:  CLK gate:  1'd1 }, reset { wire:  RST_N }, 32'd32, 32'd0]
				   []
				   meth types=[([], Nothing, Just (Bit 32)), ([Bit 32], Just (Bit 1), Nothing)]
				   port types=D_IN -> Prelude.Bit 32
					      Q_OUT -> Prelude.Bit 32
state :: ABSTRACT:  Prelude.VReg = RegN
				   (VModInfo
				    RegN
				    clock _clk__1(CLK, {-unused-});
				    reset _rst__1(RST) clocked_by(_clk__1);
				    [clockarg _clk__1;, resetarg _rst__1;, param width;, param init;]
				    [method (Q_OUT, [reg])read clocked_by (_clk__1) reset_by (_rst__1);,
				     method write((D_IN, [reg])) enable ((EN,
									  [])) clocked_by (_clk__1) reset_by (_rst__1);]
				    SchedInfo [read CF read, read SB write, write SBR write] [] [] []
				    [])
				   [clock { osc:  CLK gate:  1'd1 }, reset { wire:  RST_N }, 32'd1, 1'd0]
				   []
				   meth types=[([], Nothing, Just (Bit 1)), ([Bit 1], Just (Bit 1), Nothing)]
				   port types=D_IN -> TestBench.State
					      Q_OUT -> TestBench.State
-- AP local definitions
x__h274 :: Bit 32;
x__h274  = _read__h113 + 32'd1;
-- IdProp x__h274[IdP_keep]
NOT_proc_cpuToHost_BITS_31_TO_0_2_EQ_0_5___d17 :: Bit 1;
NOT_proc_cpuToHost_BITS_31_TO_0_2_EQ_0_5___d17  = ! proc_cpuToHost_BITS_31_TO_0_2_EQ_0___d15;
-- IdProp NOT_proc_cpuToHost_BITS_31_TO_0_2_EQ_0_5___d17[IdP_from_rhs]
NOT_state___d3 :: Bit 1;
NOT_state___d3  = ! state___d2;
-- IdProp NOT_state___d3[IdP_from_rhs]
proc_RDY_cpuToHost_AND_state___d8 :: Bit 1;
proc_RDY_cpuToHost_AND_state___d8  = proc_RDY_cpuToHost____d7 && state___d2;
-- IdProp proc_RDY_cpuToHost_AND_state___d8[IdP_from_rhs]
proc_RDY_hostToCpu_AND_NOT_state___d4 :: Bit 1;
proc_RDY_hostToCpu_AND_NOT_state___d4  = proc_RDY_hostToCpu____d1 && NOT_state___d3;
-- IdProp proc_RDY_hostToCpu_AND_NOT_state___d4[IdP_from_rhs]
proc_cpuToHost_BITS_36_TO_32_0_EQ_21_4_AND_pro_ETC___d16 :: Bit 1;
proc_cpuToHost_BITS_36_TO_32_0_EQ_21_4_AND_pro_ETC___d16  = proc_cpuToHost_BITS_36_TO_32_0_EQ_21___d14 &&
							    proc_cpuToHost_BITS_31_TO_0_2_EQ_0___d15;
-- IdProp proc_cpuToHost_BITS_36_TO_32_0_EQ_21_4_AND_pro_ETC___d16[IdP_from_rhs]
proc_cpuToHost_BITS_36_TO_32_0_EQ_21_4_AND_NOT_ETC___d18 :: Bit 1;
proc_cpuToHost_BITS_36_TO_32_0_EQ_21_4_AND_NOT_ETC___d18  = proc_cpuToHost_BITS_36_TO_32_0_EQ_21___d14 &&
							    NOT_proc_cpuToHost_BITS_31_TO_0_2_EQ_0_5___d17;
-- IdProp proc_cpuToHost_BITS_36_TO_32_0_EQ_21_4_AND_NOT_ETC___d18[IdP_from_rhs]
proc_cpuToHost_BITS_36_TO_32_0_EQ_18___d11 :: Bit 1;
proc_cpuToHost_BITS_36_TO_32_0_EQ_18___d11  = idx__h323 == 5'd18;
-- IdProp proc_cpuToHost_BITS_36_TO_32_0_EQ_18___d11[IdP_from_rhs]
proc_cpuToHost_BITS_36_TO_32_0_EQ_19___d13 :: Bit 1;
proc_cpuToHost_BITS_36_TO_32_0_EQ_19___d13  = idx__h323 == 5'd19;
-- IdProp proc_cpuToHost_BITS_36_TO_32_0_EQ_19___d13[IdP_from_rhs]
proc_cpuToHost_BITS_36_TO_32_0_EQ_21___d14 :: Bit 1;
proc_cpuToHost_BITS_36_TO_32_0_EQ_21___d14  = idx__h323 == 5'd21;
-- IdProp proc_cpuToHost_BITS_36_TO_32_0_EQ_21___d14[IdP_from_rhs]
proc_cpuToHost_BITS_31_TO_0_2_EQ_0___d15 :: Bit 1;
proc_cpuToHost_BITS_31_TO_0_2_EQ_0___d15  = data__h324 == 32'd0;
-- IdProp proc_cpuToHost_BITS_31_TO_0_2_EQ_0___d15[IdP_from_rhs]
idx__h323 :: Bit 5;
idx__h323  = extract ab__h316 32'd36 32'd32;
-- IdProp idx__h323[IdP_keep]
data__h324 :: Bit 32;
data__h324  = extract ab__h316 32'd31 32'd0;
-- IdProp data__h324[IdP_keep]
proc_RDY_cpuToHost____d7 :: Bit 1;
proc_RDY_cpuToHost____d7  = proc.RDY_cpuToHost;
-- IdProp proc_RDY_cpuToHost____d7[IdP_from_rhs]
proc_RDY_hostToCpu____d1 :: Bit 1;
proc_RDY_hostToCpu____d1  = proc.RDY_hostToCpu;
-- IdProp proc_RDY_hostToCpu____d1[IdP_from_rhs]
state___d2 :: Bit 1;
state___d2  = state.read;
-- IdProp state___d2[IdP_from_rhs]
_read__h113 :: Bit 32;
_read__h113  = cycle.read;
-- IdProp _read__h113[IdP_keep]
ab__h316 :: Bit 37;
ab__h316  = proc.cpuToHost;
-- IdProp ab__h316[IdP_keep]
-- AP rules
rule RL_start "start":
 when proc_RDY_hostToCpu_AND_NOT_state___d4
  ==> { proc.hostToCpu 32'h1000; state.write 1'd1; }
[]
clock domain = Just (0), resets = [0]
rule RL_countCycle "countCycle":
 when state___d2
  ==> { cycle.write x__h274; Prelude.$display "\ncycle %d" _read__h113; }
[]
clock domain = Just (0), resets = [0]
rule RL_run "run":
 when proc_RDY_cpuToHost_AND_state___d8
  ==> { proc.cpuToHost;
	if proc_cpuToHost_BITS_36_TO_32_0_EQ_18___d11 then Prelude.$fwrite 32'd2147483650 "%d" data__h324;
	if proc_cpuToHost_BITS_36_TO_32_0_EQ_19___d13 then Prelude.$fwrite 32'd2147483650 "%c" data__h324;
	if proc_cpuToHost_BITS_36_TO_32_0_EQ_21_4_AND_pro_ETC___d16 then
	  Prelude.$fwrite 32'd2147483650 "PASSED\n";
	if proc_cpuToHost_BITS_36_TO_32_0_EQ_21_4_AND_NOT_ETC___d18 then
	  Prelude.$fwrite 32'd2147483650 "FAILED %d\n" data__h324;
	if proc_cpuToHost_BITS_36_TO_32_0_EQ_21___d14 then Prelude._finish_ 32'd1; }
[]
clock domain = Just (0), resets = [0]
-- AP scheduling pragmas
[]
-- AP interface
-- AP instance comments
-- AP remaining proof obligations
[]

-----
