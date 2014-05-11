--module Netlist where

import DataTypes
import CalledMethods
import Scheduler
import Data.Map
import Conflict
import ModuleParser
import Text.Parsec
import Debug.Trace

allInfo :: ModuleIfcs -> Module -> (ModuleName,
                                    Map BindName Binding,
                                    Map InstName Inst,
                                    Map FpName (Bool, [(ArgName, Integer)]),
                                    Map DefinedMethod (Bool, [(ArgName, Integer)]),
                                    Map CalledMethod (Bool, [ArgName]),
                                    Map PriorityElem [PriorityElem])
allInfo modIfcs mod = (modName, binds, insts, fops, meths, calledMeth, sch)
  where
    modName = moduleName mod
    binds = bindings mod
    insts = instances mod
    fops = fromList [ (fpName, (case typ of
                                  Value _ -> args == []
                                  otherwise -> False,
                                args)) | (fpName, Fp typ args) <- toList $ fps mod]
    meths = fromList [ (name, (case typ of
                                 Value _ -> args == []
                                 otherwise -> False,
                               args)) | (name, Method typ args _) <- toList $ methods mod]
    calledMeth = getCalledMethods modIfcs mod
    sch = scheduler modIfcs mod

getModuleIfc ::
  ModuleIfcs
  -> Module
  -> ModuleIfc
getModuleIfc modIfcs mod =
  ModuleIfc
    (keys (fps mod))
    (fromList [(k, (isV0 k, args k, fpu modIfcs mod k)) | k <- meths])
    (fromList [((k1, k2), fullCm modIfcs mod k1 k2) | k1 <- meths, k2 <- meths ])
  where
    getMeths k = methods mod ! k
    meths = keys $ methods mod
    isV0 k = case (methodType $ getMeths k) of
               Value _ -> methodArgs (getMeths k) == []
               otherwise -> False
    args k = [x | (x, y) <- methodArgs (getMeths k)]

buildModuleIfc :: ModuleIfcs -> Module -> ModuleIfcs
buildModuleIfc modIfcs mod = insert (moduleName mod) (traceId $ getModuleIfc modIfcs mod) modIfcs

main = do
  input <- getContents
  case (parse modulesParser "" input) of
    Left _ -> putStrLn "Error"
    Right mods -> do
      --putStrLn $ show mods
      let modIfcs = Prelude.foldl (\acc m -> buildModuleIfc acc m) empty mods
      putStrLn $ "\n\n\n\n---------------------------------------------------------------------------\n" ++ show [allInfo modIfcs x | x <- mods]
      --putStrLn $ show modIfcs
      return ()
