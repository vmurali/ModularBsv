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
    [x | Fp x _ _ <- fps mod]
    (fromList [(k, (isV0 k, args k, fpu modIfcs mod k)) | k <- meths])
    (fromList [((k1, k2), fullCm modIfcs mod ("this",k1) ("this",k2)) | k1 <- meths, k2 <- meths ])
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
  parsed <- parseFromFile modulesParser "../TestCase/output"
  --input <- getContents
  --let parsed = parse modulesParser "" input
  case (parsed) of
    Left error -> putStrLn $ show error
    Right mods -> do
      let modIfcs = Prelude.foldl (\acc m -> buildModuleIfc acc m) empty mods
      --putStrLn $ show mods
      --putStrLn $ show [(moduleName mod, priorityList mod) | mod <- mods]
      let allInfos = [allInfo modIfcs x| x <- mods]
      let fcalledms = [(name,s)| (name, bs, _, _, _, f, calledms, s) <- allInfos]
      putStrLn $ show fcalledms
      --let (bsproc, fproc, cmsproc) = head [(bs, f, calledms) | (name, bs, f, calledms) <- fcalledms, name == "mkProc"]
      --putStrLn $ show $ (keys cmsproc)
      --putStrLn $ show $ length $ concat [y | (x, Binding _ _ (Expr _ y)) <- toList bsproc]
      --putStrLn $ show $ length (keys bsproc)
      --putStrLn $ show [(cm, fproc cm)| cm <- keys cmsproc]
      --putStrLn $ show $ ([(moduleName mod, getBothCaller mod ("thomas", "murali")) | mod <- mods])
      --putStrLn $ show (calledm1504, calledm1505, calledm1506)
      --putStrLn $ show (length calledms)
      --putStrLn $ show (calledms !! 1504, calledms !! 1505, calledms !! 1506)
      return ()
