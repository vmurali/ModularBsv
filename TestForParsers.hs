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
parseTest formalParametersParser "fp:\n(fdsk fdsf fds )\n  fd:\n (fkdjsk ghr ghfd t4reh)"


--BAD : Weak, -> TODO

parseTest bindingParser "a : Bit 6 ;\n a =  c ++ b && c;"
parseTest bindingParser "a : Bit 6 ;\n a =  c && b && c;"
parseTest bindingParser "a : Bit 6 ;\n a =  c && b ++ c;"
