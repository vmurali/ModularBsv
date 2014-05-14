module Netlist where

import DataTypes
import CalledMethods
import Scheduler
import Data.Map
import Conflict
import ModuleParser
import Text.Parsec
import Text.Parsec.String
import Debug.Trace
import qualified Data.List as L

allInfo :: ModuleIfcs -> Module -> (ModuleName,
                                    Map BindName Binding,
                                    Map InstName Inst,
                                    Map FpName (Bool, [(ArgName, Integer)]),
                                    Map DefinedMethod (Bool, [(ArgName, Integer)]),
                                    Map CalledMethod [(ThisName, String, [ArgName])],
                                    Map CalledMethod (Bool, [ArgName]),
                                    Map PriorityElem [PriorityElem])
allInfo modIfcs mod = (modName, binds, insts, fops, meths, bothCallers, calledMeth, sch)
  where
    modName = moduleName mod
    binds = bindings mod
    insts = instances mod
    fops = fromList [ (fpName, (case typ of
                                  Value _ -> args == []
                                  otherwise -> False,
                                args)) | Fp fpName typ args <- fps mod]
    meths = fromList [ (name, (case typ of
                                 Value _ -> args == []
                                 otherwise -> False,
                               args)) | (name, Method typ args _) <- toList $ methods mod]
    bothCallers = getBothCaller mod
    calledMeth = getCalledMethods modIfcs mod
    sch = scheduler modIfcs mod

getModuleIfc ::
  ModuleIfcs
  -> Module
  -> ModuleIfc
getModuleIfc modIfcs mod =
  ModuleIfc
    (fps mod)
    (fromList [(k, (methodType $ getMeths k, methodArgs $ getMeths k, fpu modIfcs mod k)) | k <- meths])
    (fromList [((k1, k2), fullCm modIfcs mod ("this",k1) ("this",k2)) | k1 <- meths, k2 <- meths ])
  where
    getMeths k = methods mod ! k
    meths = keys $ methods mod

buildModuleIfc :: ModuleIfcs -> Module -> ModuleIfcs
buildModuleIfc modIfcs mod = let gMod = getModuleIfc modIfcs mod in
  insert (moduleName mod) gMod modIfcs

ehrList = [0..2]

ehrIfc = ModuleIfc []
  (fromList $ [("r" ++ show x, (Value 0, [], [])) | x <- ehrList] ++ [("w" ++ show x, (Action, [("x", 0)], [])) | x <- ehrList])
  (fromList $
      ([(("r" ++ show x, "r" ++ show y), if x < y then SB else if x == y then CF else SA)| x <- ehrList, y <- ehrList] ++
       [(("r" ++ show x, "w" ++ show y), if x <= y then SB else SA)| x <- ehrList, y <- ehrList] ++
       [(("w" ++ show x, "r" ++ show y), if x < y then SB else SA)| x <- ehrList, y <- ehrList] ++
       [(("w" ++ show x, "w" ++ show y), if x < y then SB else if x == y then C else SA)| x <- ehrList, y <- ehrList]))

regFileIfc = ModuleIfc []
  (fromList [("sub", (Value 1, [("x", 0)], [])), ("upd", (Action, [("x", 0), ("y", 0)], []))])
  (fromList [(("sub", "sub"), C), (("upd", "upd"), C), (("sub", "upd"), SB), (("upd", "sub"), SA)])
