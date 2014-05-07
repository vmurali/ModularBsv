module Conflict where

import Control.Monad
import Control.Exception (assert)
import Control.Applicative hiding ((<|>), many)
import Data.Char
import qualified Data.List as List
import qualified Data.Maybe as Maybe
import qualified Data.Map as Map
import qualified Data.String.Utils as S
import qualified Data.Either as E
import qualified Data.Set.Monad as Set

import Algebra.Lattice  --SOOOO COOOL

import DataTypes
import Debug.Trace

instance JoinSemiLattice (Conflict) where
  join C C = C
  join C CF = C
  join CF C = C
  join C SA = C
  join C SB = C
  join SA C = C
  join SB C = C
  join SA SB = C
  join SB SA = C
  join CF SA = SA
  join SA SA = SA
  join SA CF = SA
  join CF SB = SB
  join SB SB = SB
  join SB CF = SB
  join CF CF = CF

toActualArgs ::
  ModuleIfcs
  -> Map.Map InstName [CalledMethod]
  -> Map.Map InstName ModuleName
  -> CalledMethod
  -> Set.Set CalledMethod
toActualArgs moduleIfcs instToArgs instToModule (m1, h1) =
  foldl (\acc x -> Set.insert (fpsToArgs Map.! x) acc) Set.empty fpsMeth
  where
    fpsMeth = (fpsForMethodInModule $ (moduleIfcs Map.! (instToModule Map.! m1))) Map.! h1
    fpsMod = fpsInModule (moduleIfcs Map.! (instToModule Map.! m1))
    fpsToArgs = Map.fromList $ zip fpsMod (instToArgs Map.! m1)

cmCalledMethods ::
  ModuleIfcs
  -> Map.Map InstName [CalledMethod]
  -> Map.Map InstName ModuleName
  -> (Map.Map (FpName, FpName) Conflict)
  -> Set.Set CalledMethod
  -> Map.Map (CalledMethod, CalledMethod) Conflict
cmCalledMethods moduleIfcs instToArgs instToModule fpConf calles =
  Set.foldl
    (\acc1 (m1, h1) -> Set.foldl
          (\acc2 (m2, h2) ->  Map.insert 
                ((m1,h1),(m2,h2))
                (conflict ((m1,h1),(m2,h2)))
                acc2)
          acc1
          calles
          )
    Map.empty
    calles
  where 
    conflict ((m1,h1),(m2,h2))
      | m1 == "fp" , m2 == "fp" = fpConf Map.! (h1, h2)
         | m1 == m2 = (cmForMethodsInModule $ moduleIfcs Map.! (instToModule Map.! m1)) Map.! (h1,h2)
      | m1 == "fp" = let actCalles = Set.toList $ toActualArgs moduleIfcs instToArgs instToModule (m2, h2) in
                       joins1 [conflict ((m1, h1), p) | p <- actCalles]
      | m2 == "fp" = let actCalles = Set.toList $ toActualArgs moduleIfcs instToArgs instToModule (m1, h1) in
                       joins1 [conflict (p, (m2, h2)) | p <- actCalles]
      | otherwise =
          let actCalles1 = Set.toList $ toActualArgs moduleIfcs instToArgs instToModule (m1, h1)
              actCalles2 = Set.toList $ toActualArgs moduleIfcs instToArgs instToModule (m2, h2) in
          joins1 [conflict (x, y) | x <- actCalles1, y <- actCalles2]

fullCm ::
  ModuleIfcs
  -> Map.Map InstName [CalledMethod]
  -> Map.Map InstName ModuleName
  -> (Map.Map (FpName, FpName) Conflict)
  -> Map.Map ThisName (Set.Set CalledMethod)
  -> Set.Set DefinedMethod -- The set of value0 methods
  -> Map.Map (ThisName, ThisName) Conflict
fullCm moduleIfcs instToArgs instToModule fpConf nameToCalles value0s =
  foldl
    (\acc1 n1 -> foldl
        (\acc2 n2 -> Map.insert (n1, n2)
                       (if n1 == n2
                          then (if Set.member n1 value0s
                                  then CF
                                  else C)
                          else (joins1 [cmCalled Map.! p| p <- confSet n1 n2])) acc2)
        acc1
        allNames
    )
    Map.empty
    allNames
  where
    allNames = Map.keys nameToCalles
    calles = Map.fold (\x acc -> Set.union x acc) Set.empty nameToCalles
    cmCalled = cmCalledMethods moduleIfcs instToArgs instToModule fpConf calles
    confSet n1 n2 = [(x,y) | x <- (Set.toList $ nameToCalles Map.! n1), y <- (Set.toList $ nameToCalles Map.! n2)]

fpu ::
  ModuleIfcs
  -> Map.Map InstName [CalledMethod]
  -> Map.Map InstName ModuleName
  -> Map.Map DefinedMethod (Set.Set CalledMethod)
  -> Map.Map DefinedMethod (Set.Set FpName)
fpu moduleIfcs instToArgs instToModule defToCalles =
  foldl (\acc d -> Map.insert d (Set.fromList (getFpus $ Set.toList (defToCalles Map.! d))) acc) Map.empty defs
  where
    defs = Map.keys defToCalles
    getFpus [] = []
    getFpus ((m, h) : xs)
      | m == "fp" = h : getFpus xs
      | otherwise = getFpus (Set.toList (toActualArgs moduleIfcs instToArgs instToModule (m, h)) ++ xs)

{-
getModuleIfc ::
  ModuleIfcs
  -> Module
  -> ModuleIfc
getModuleIfc moduleIfcs mod =
  where
-}
