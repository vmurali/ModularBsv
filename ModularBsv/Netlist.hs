--module Netlist where

import DataTypes
import CalledMethods
import Scheduler
import Data.Map
import Conflict
import ModuleParser
import Text.Parsec
import Text.Parsec.String
import Debug.Trace

allInfo :: ModuleIfcs -> Module -> (ModuleName,
                                    Map BindName Binding,
                                    Map InstName Inst,
                                    Map FpName (Bool, [(ArgName, Integer)]),
                                    Map DefinedMethod (Bool, [(ArgName, Integer)]),
                                    (CalledMethod -> [(ThisName, String, [ArgName])]),
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
                                args)) | (fpName, Fp typ args) <- toList $ fps mod]
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
buildModuleIfc modIfcs mod = let gMod = getModuleIfc modIfcs mod in
  insert (moduleName mod) gMod modIfcs

main = do
  --filename <- getLine
  --parsed <- parseFromFile modulesParser filename
  parsed <- parseFromFile modulesParser "../TestCase/output"
  case (parsed) of
    Left _ -> putStrLn "Error"
    Right mods -> do
      let modIfcs = Prelude.foldl (\acc m -> buildModuleIfc acc m) empty mods
      let allInfos = [allInfo modIfcs x| x <- mods]
      let calledms = [(calledm, f calledm)| (_, _, _, _, _, f, calledms, _) <- allInfos, calledm <- keys calledms]
      --putStrLn $ show [getBothCaller mod ("hell", "heaven")| mod <- mods, moduleName mod == "mkProc"]
      let (calledm1504, _) = calledms !! 1504
      let (calledm1505, _) = calledms !! 1505
      let (calledm1506, _) = calledms !! 1506
      --putStrLn $ show $ ([(moduleName mod, getBothCaller mod ("thomas", "murali")) | mod <- mods])
      --putStrLn $ show (calledm1504, calledm1505, calledm1506)
      --putStrLn $ show (length calledms)
      --putStrLn $ show (calledms !! 1504, calledms !! 1505, calledms !! 1506)
      return ()
