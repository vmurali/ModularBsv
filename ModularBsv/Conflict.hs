module Conflict where

import qualified Data.List as List
import qualified Data.Map as Map

import Algebra.Lattice  --SOOOO COOOL

import DataTypes
import CalledMethods

instance JoinSemiLattice (Conflict) where
  join SA SB = C
  join SB SA = C
  join C _ = C
  join _ C = C
  join CF x = x
  join x CF = x

instToModule mod m = instModule $ instances mod Map.! m
instToArgs mod m = instArgs $ instances mod Map.! m

toActualArgs ::
  ModuleIfcs
  -> Module
  -> CalledMethod
  -> [CalledMethod]
toActualArgs moduleIfcs mod (m1, h1) =
  foldl (\acc x -> (fpsToArgs Map.! x) : acc) [] fpsMeth
  where
    fpsMeth = (fpsForMethodInModule $ (moduleIfcs Map.! (instToModule mod m1))) Map.! h1
    fpsMod = fpsInModule (moduleIfcs Map.! (instToModule mod m1))
    fpsToArgs = Map.fromList $ zip fpsMod (instToArgs mod m1)

cmCalledMethods ::
  ModuleIfcs
  -> Module
  -> CalledMethod
  -> CalledMethod
  -> Conflict
cmCalledMethods moduleIfcs mod (m1, h1) (m2, h2)
  | m1 == "fp" || m1 == "fp1" || m1 == "fp2" , m2 == "fp" || m2 == "fp1" || m2 == "fp2" = fpConflict mod Map.! (h1, h2)
  | m1 == m2 = (cmForMethodsInModule $ moduleIfcs Map.! (instToModule mod m1)) Map.! (h1,h2)
  | m1 == "fp" || m1 == "fp1" || m1 == "fp2" = joins1 [cmCalledMethods moduleIfcs mod (m1, h1) q | q <- actCalles2]
  | m2 == "fp" || m2 == "fp1" || m2 == "fp2" = joins1 [cmCalledMethods moduleIfcs mod p (m2, h2) | p <- actCalles1]
  | m1 == "this" = joins1 [cmCalledMethods moduleIfcs mod p (m2, h2) | p <- getCalled mod h1] --hack
  | m2 == "this" = joins1 [cmCalledMethods moduleIfcs mod (m1, h1) q | q <- getCalled mod h2] --hack
  | otherwise = joins1 [cmCalledMethods moduleIfcs mod p q | p <- actCalles1, q <- actCalles2]
  where
    actCalles1 = toActualArgs moduleIfcs mod (m1, h1)
    actCalles2 = toActualArgs moduleIfcs mod (m2, h2)

fullCm ::
  ModuleIfcs
  -> Module
  -> ThisName
  -> ThisName
  -> Conflict
fullCm moduleIfcs mod x1 x2 =
  if x1 == x2 && Map.member x1 (methods mod)
    then if margs == [] && isValue
           then CF
           else C
    else joins1 [cmCalledMethods moduleIfcs mod p q | p <- hs1, q <- hs2]
  where
    margs = methodArgs $ methods mod Map.! x1
    mtype = methodType $ methods mod Map.! x1
    isValue = case mtype of
                Value _ -> True
                otherwise -> False
    hs1 = getCalled mod x1
    hs2 = getCalled mod x2

fpu ::
  ModuleIfcs
  -> Module
  -> DefinedMethod
  -> [FpName]
fpu moduleIfcs mod def =
  getFpus $ getCalled mod def
  where
    getFpus [] = []
    getFpus ((m, h) : xs)
      | m == "fp" || m == "fp1" || m == "fp2" = h : getFpus xs
      | otherwise = getFpus (toActualArgs moduleIfcs mod (m, h) ++ xs)

getModuleIfc ::
  ModuleIfcs
  -> Module
  -> ModuleIfc
getModuleIfc modIfcs mod =
  ModuleIfc
    (Map.keys (fps mod))
    (Map.fromList [(k, fpu modIfcs mod k) | k <- meths])
    (Map.fromList [((k1, k2), fullCm modIfcs mod k1 k2) | k1 <- meths, k2 <- meths ])
  where
    meths = Map.keys $ methods mod
