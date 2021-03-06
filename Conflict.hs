module Conflict where

import qualified Data.List as List
import qualified Data.Map as Map
import Control.Monad
import Data.Char
import qualified Data.Maybe as Maybe
import qualified Data.String.Utils as S
import qualified Data.Either as E
import qualified Data.Set.Monad as Set
import Debug.Trace

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
  join SA SA = SA
  join SB SB = SB

instance BoundedJoinSemiLattice (Conflict) where
  bottom = CF

instance Ord a => JoinSemiLattice (Set.Set a) where
  join x y = Set.union x y

instance Ord a => BoundedJoinSemiLattice (Set.Set a) where
  bottom = Set.empty

instToModule mod m = instModule $ instances mod Map.! m
instToArgs mod m = instArgs $ instances mod Map.! m

toActualArgs ::
  ModuleIfcs
  -> Module
  -> CalledMethod
  -> [CalledMethod]
toActualArgs moduleIfcs mod (m1, h1) = List.nub $
  foldl (\acc x -> (fpsToArgs Map.! x) : acc) [] fpsMeth
  where
    (_, _, fpsMeth) = (methodsInModule $ (moduleIfcs Map.! (instToModule mod m1))) Map.!  h1 
    fpsMod = map fpName $ fpsInModule (moduleIfcs Map.! (instToModule mod m1))
    fpsToArgs = Map.fromList $ zip fpsMod (instToArgs mod m1)

cmCalledMethods :: ModuleIfcs -> Module -> CalledMethod -> CalledMethod -> Conflict
cmCalledMethods modIfcs mod x y =
  joins . map (basicConflict modIfcs mod) . Set.toList $ dependenciesAll modIfcs mod (x,y)
 
basicConflict modIfcs mod ((m1, h1),(m2, h2))
								| fpM m1, fpM m2 =(fpConflict mod) Map.! (h1,h2)  
								| m1 == m2 = (cmForMethodsInModule $ modIfcs Map.! instToModule mod m1 ) Map.! (h1,h2)
								| otherwise  = CF 

buildDependenciesFunction modIfcs mod ((m1, h1),(m2, h2))   
							| fpM m1 , fpM m2 = Set.singleton ((m1,h1),(m2,h2))   
					   	| m1 == m2 = Set.singleton ((m1,h1),(m2,h2))
					   	| fpM m1 = Set.fromList . map (\p -> ((m1,h1),p)) $ listFps2
					   	| fpM m2 = Set.fromList . map (\p->  (p,(m2,h2))) $ listFps1
					   	| otherwise = Set.fromList $ [(x,y) | x <- listFps1, y <- listFps2]  
	where
 		listFps1 = toActualArgs modIfcs mod (m1,h1) 
		listFps2 = toActualArgs modIfcs mod (m2,h2) 

dependenciesExpand :: ModuleIfcs -> Module -> Set.Set (CalledMethod, CalledMethod) -> Set.Set (CalledMethod, CalledMethod)
dependenciesExpand modIfcs mod x = Set.union (buildDependenciesFunction modIfcs mod =<< x) x

dependenciesAll :: ModuleIfcs -> Module -> (CalledMethod, CalledMethod) -> Set.Set (CalledMethod, CalledMethod)
dependenciesAll modIfcs mod x = lfpFrom (Set.singleton x) (dependenciesExpand modIfcs mod)

thisM m = m == "this"

fullCm ::
  ModuleIfcs
  -> Module
  -> PriorityElem
  -> PriorityElem
  -> Conflict
fullCm moduleIfcs mod (m1, x1) (m2, x2) =
 if thisM m1 && thisM m2 && x1 == x2 && Map.member x1 (methods mod)
   then if margs == [] && isValue
          then CF
          else C
   else   joins [cmCalledMethods moduleIfcs mod p q | p <- hs1, q <- hs2]
  where
    margs = methodArgs $ methods mod Map.! x1
    mtype = methodType $ methods mod Map.! x1
    isValue = case mtype of
                Value _ -> True
                otherwise -> False
    hs1 = if thisM m1 && (Map.member x1 (rules mod) || Map.member x1 (methods mod))
            then getCalled mod x1
            else [(m1, x1)]
    hs2 = if thisM m2 && (Map.member x2 (rules mod) || Map.member x2 (methods mod))
            then getCalled mod x2
            else [(m2, x2)]

primitive mod = moduleName mod == "mkRegFile" || moduleName mod == "mkEHR" 

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
      | fpM m = h : getFpus xs
      | otherwise = getFpus (List.nub $ toActualArgs moduleIfcs mod (m, h) ++ xs)
