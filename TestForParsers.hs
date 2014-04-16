-- The parsers are designed to be used on the output of the BSC -dATS compiler.
-- Hence, they are supposed to be used on well formed expressions. 
-- No work to raise exceptions, no defensive programming.

--GOOD
parseTest bindingParser "a : Bit 6 ;\n a = b ++c ;"
parseTest bindingParser "a : Bit 6 ;\n a = b && c;"
parseTest bindingParser "a : Bit 6 ;\n a = b ++ c ++ d;"
parseTest bindingParser "a : Bit 6 ;\n a = b ++ 8'd554;"
parseTest bindingParser "a : Bit 6 ;\n a = b || c;"
parseTest bindingParser "a : Bit 6 ;\n a = b && c;"
parseTest bindingParser "a : Bit 6 ;\n a =_if_ a b c;"



parseTest ruleParser " rule a \"test\":\n when 1'd1 \n ==> { copFifo_enqP_rl.write x__h1832; }"
parseTest ruleParser " rule a \"test\":\n when 1'd1 \n ==> { if IF_copFifo_enqEn_dummy2_2_0_THEN_IF_copFifo_en_ETC___d92 then\n	  copFifo_enqEn_lat_2.wset 1'd1;\n	if IF_copFifo_enqEn_dummy2_2_0_THEN_IF_copFifo_en_ETC___d92 then copFifo_enqEn_dummy2_2.write 1'd1;}"
parseTest ruleParser "rule a \"test\": when fdsg1_fds ==> {    if wr_rindx_EQ_5___d5 then rfile_5.write wr_data;\n         if wr_rindx_EQ_6___d6 then rfile_6.write wr_data;\n         if wr_rindx_EQ_7___d7 then rfile_7.write wr_data;\n         if wr_rindx_EQ_8___d8 then rfile_8.write wr_data;\n         if wr_rindx_EQ_9___d9 then rfile_9.write wr_data;\n         if wr_rindx_EQ_10___d10 then rfile_10.write wr_data;\n         if wr_rindx_EQ_11___d11 then rfile_11.write wr_data;\n         if wr_rindx_EQ_12___d12 then rfile_12.write wr_data;\n         if wr_rindx_EQ_13___d13 then rfile_13.write wr_data;\n         if wr_rindx_EQ_14___d14 then rfile_14.write wr_data;\n         if wr_rindx_EQ_15___d15 then rfile_15.write wr_data;\n         if wr_rindx_EQ_16___d16 then rfile_16.write wr_data;\n         if wr_rindx_EQ_17___d17 then rfile_17.write wr_data;\n         if wr_rindx_EQ_18___d18 then rfile_18.write wr_data;\n         if wr_rindx_EQ_19___d19 then rfile_19.write wr_data;\n         if wr_rindx_EQ_20___d20 then rfile_20.write wr_data;\n         if wr_rindx_EQ_21___d21 then rfile_21.write wr_data;\n         if wr_rindx_EQ_22___d22 then rfile_22.write wr_data;\n         if wr_rindx_EQ_23___d23 then rfile_23.write wr_data;\n         if wr_rindx_EQ_24___d24 then rfile_24.write wr_data;\n         if wr_rindx_EQ_25___d25 then rfile_25.write wr_data;\n}\n"



parseTest methodParser "[rule start \"start\":  when 1'd1 \n   ==> { startReg.write 1'd1; } []\n clock domain = Just (0), resets = [0]]"
parseTest methodParser "wr_idx :: Bit 7;\n wr_val :: Bit 32;\n [rule wr \"wr\":\n when 1'd1\n   ==> { if wr_idx_BIT_6_36_AND_wr_idx_BIT_5_37_38_AND_IF__ETC___d146 then \n   copFifo_tempData_lat_0.wset IF_IF_wr_idx_BIT_6_36_THEN_wr_idx_BITS_4_TO_0__ETC___d149;\n	 if wr_idx_BIT_6_36_AND_wr_idx_BIT_5_37_38_AND_IF__ETC___d146 then \n	   copFifo_tempData_dummy2_0.write 1'd1;\n	 if wr_idx_BIT_6_36_AND_wr_idx_BIT_5_37_38_AND_IF__ETC___d146 then \n	   copFifo_tempEnqP_lat_0.wset _4_CONCAT_IF_copFifo_enqP_dummy2_0_50_AND_copFi_ETC___d156;\n	 if wr_idx_BIT_6_36_AND_wr_idx_BIT_5_37_38_AND_IF__ETC___d146 then \n	   copFifo_tempEnqP_dummy2_0.write 1'd1;\n	 if wr_idx_BIT_6_36_AND_wr_idx_BIT_5_37_38_AND_IF__ETC___d146 then copFifo_enqP_lat_0.wset x__h13664; \n	 if wr_idx_BIT_6_36_AND_wr_idx_BIT_5_37_38_AND_IF__ETC___d146 then copFifo_enqP_dummy2_0.write 1'd1;\n	 if wr_idx_BIT_6_36_AND_wr_idx_BIT_5_37_38_AND_IF__ETC___d146 then copFifo_enqEn_lat_0.wset 1'd0; \n	 if wr_idx_BIT_6_36_AND_wr_idx_BIT_5_37_38_AND_IF__ETC___d146 then copFifo_enqEn_dummy2_0.write 1'd1;	 numInsts.write x__h15042; } \n[]\n clock domain = Just (0), resets = [0]]"



parseTest formalParametersParser "fp: \n(fdsk fdsjkh rewjh)\n pasta: (fdskj fdslj)\n"
parseTest formalParametersParser "fp:\n(fdsk fdsf fds )\n  fd:\n \n (fkdjsk ghr ghfd t4r_eh)"

--Without formal parameters
parseTest instancesParser "mem :: ABSTRACT:  RegFile.VRegFile = RegFileLoad\n				     (VModInfo\n				      RegFileLoad\n				      clock _clk__1(CLK, {-unused-});\n				      [clockarg _clk__1;,\n				       param file;,\n				       param addr_width;,\n				       param data_width;,\n				       param lo;,\n				       param hi;,\n				       param binary;]\n				      [method upd((ADDR_IN, []), (D_IN, [reg])) enable ((WE,\n											 [])) clocked_by (_clk__1) reset_by (no_reset);,\n				       method (D_OUT, [])sub[5]((ADDR, [])) clocked_by (_clk__1) reset_by (no_reset);]\n				      SchedInfo [sub CF sub, sub SB upd, upd C upd] [] [] []\n				      [])\n				     [clock { osc:  CLK gate:  1'd1 },\n				      \"memory.vmh\",\n				      32'd26,\n				      32'd32,\n				      26'h0,\n				      26'd67108863,\n				      1'd0]\n				     []\n				     meth types=[([Bit 26, Bit 32], Just (Bit 1), Nothing),\n						 ([Bit 26], Nothing, Just (Bit 32))]\n				     port types=ADDR_1 -> Prelude.Bit 26\n						ADDR_2 -> Prelude.Bit 26\n						ADDR_3 -> Prelude.Bit 26\n						ADDR_4 -> Prelude.Bit 26\n						ADDR_5 -> Prelude.Bit 26\n						ADDR_IN -> Prelude.Bit 26\n						D_IN -> Prelude.Bit 32\n						D_OUT_1 -> Prelude.Bit 32\n						D_OUT_2 -> Prelude.Bit 32\n						D_OUT_3 -> Prelude.Bit 32\n						D_OUT_4 -> Prelude.Bit 32\n						D_OUT_5 -> Prelude.Bit 32\n-- AP local definitions\ni__h241 :: Bit 26;\ni__h241  = extract req_a 32'd27 32'd2;\n-- IdProp i__h241[IdP_keep]\n-- AP rules\n-- AP scheduling pragmas\n[]\n-- AP interface\n-- AP  apkg_interface def mkIMemory\n--AIDef req\nreq_a :: Bit 32;\nreq :: Bit 32;\nreq  = mem.sub i__h241;\npred:  RDY_req\nclock domain = Just (0), resets = []\nmethod (req, [])req((req_a, [])) clocked_by (default_clock) reset_by (no_reset);\n\n-- AP  apkg_interface def mkIMemory\n--AIDef RDY_req\nRDY_req :: Bit 1;\nRDY_req  = 1'd1;\n-- IdProp RDY_req[IdPReady]\npred:  1'b1\nclock domain = Just (0), resets = []\nmethod (RDY_req, [])RDY_req clocked_by (default_clock) reset_by (no_reset);\n\n-- AP instance comments\n-- AP remaining proof obligations\n[]\n\n"


parseTest parserMethName "method (FSds, [])kkfd((gfkj, [])) clocked_by (_clk__) reset_by (_rst__);"
parseTest ( parserMethName `sepBy` char',') "method (FSds, [])kkfd((gfkj, [])) clocked_by (_clk__) reset_by (_rst__);,\n      method gfsdkj((fdslk, []), (hgf, [])) enable ((fsder,\n     [])) clocked_by (_clk__) reset_by (_rst__);,\n      method (GDSfds, [])fsdkhj((gfd, [])) enable ((fdkdssj,\n    [])) clocked_by (_clk__) reset_by (_rst__);"

parseTest parseTripletTypes "[ Bit 2 ], Just (Bit 1), Nothing"


parseTest bodyInstanceParser "fp :: ABSTRACT:  Proc._Proc.Bla36 = mkProc_fp\n    (VModInfo\n     mkProc_fp\n     clock _clk__(CLK, CLK_GATE);\n     reset _rst__(RST) clocked_by(_clk__);\n     [resetarg _rst__;, clockarg _clk__;]\n     [method (FSds, [])kkfd((gfkj, [])) clocked_by (_clk__) reset_by (_rst__);,\n      method gfsdkj((fdslk, []), (hgf, [])) enable ((fsder,\n     [])) clocked_by (_clk__) reset_by (_rst__);,\n      method (GDSfds, [])fsdkhj((gfd, [])) enable ((fdkdssj,\n    [])) clocked_by (_clk__) reset_by (_rst__);]\n     SchedInfo\n     [fsdkhj CF gfsdkj,\n      kkfd CF fsdkhj,\n      kkfd SB gfsdkj,\n      fsdkhj C fsdkhj,\n      gfsdkj C gfsdkj]\n     []\n     []\n     []\n     [])\n    [reset { wire:  RST_N }, clock { osc:  CLK gate:  1'd1 }]\n    []\n    meth types=[([Bit 5], Nothing, Just (Bit 6)),\n([Bit 54, Bit 83], Just (Bit 1), Nothing),\n([Bit 6], Just (Bit 1), Just (Bit 1))]\n    port types=FSds -> Prelude.Bit 6\n       GDSfds -> Prelude.ActionValue (Prelude.Bit 1)\n       fdslk -> Prelude.Bit 54\n       gfd -> Prelude.Bit 6\n       gfkj -> Prelude.Bit 5\n       hgf -> Prelude.Bit 83\n\n"



--With formal parameters






--BAD : Weak, -> TODO

parseTest bindingParser "a : Bit 6 ;\n a =  c ++ b && c;"
parseTest bindingParser "a : Bit 6 ;\n a =  c && b && c;"
parseTest bindingParser "a : Bit 6 ;\n a =  c && b ++ c;"
