module Scheduler where

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

import TestParsers
import Debug.Trace


---
--- I love this stuff!
---

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
	 
---
---
---

-- I put the domains, the calles, the conflict matrix, the mapping of parameters to have the final conflict matrix
calcConflict :: Set.Set String -> Set.Set String -> Set.Set String -> (String -> Set.Set (String, String)) -> Map.Map ((String, String), (String, String)) Conflict -> Map.Map String String -> Map.Map (String,String) Conflict
calcConflict rs ms fps calles confMatrix mapFormalReal = --Haskell stuff to simplify this things!
	let union = Set.unions [rs, ms, realFp fps] in
		Set.fold 	
			(\arg1 acc1 -> Set.fold 
					(\arg2 acc2 -> Map.insert (arg1, arg2) (conflict arg1 arg2) acc2)
					acc1
					union)
			Map.empty
			union 
	where 	conflict x y = liftThisSet $ let callesx = calles x in
				let callesy = calles y in
 					Set.fold
						(\m1 acc1 -> Set.fold 
								(\m2 acc2 -> Set.union acc2  (Set.singleton $ (confMatrix Map.! (m1,m2))))
								acc1
								callesy)
						(Set.singleton CF)
						callesx
		liftThisSet = joins1 . Set.elems
		realFp set = Set.map (\x->mapFormalReal Map.! x) set

--TODO : Perhaps a structure of Map.Map String Bool is less efficient than a Set.Set String containing the scheduled methods.

--
--CORE of the scheduler
--

data BoolExpr =  ETrue
	| EFalse 
	| EAnd BoolExpr BoolExpr
	| EOr BoolExpr BoolExpr
	| ENot BoolExpr
	| EDynGuard String
	deriving(Show,Eq,Ord)

bigAnd :: [BoolExpr] -> BoolExpr
bigAnd [] = ETrue
bigAnd (t:s)= EAnd t .bigAnd $ s

-- In the scheduler, I distinguish the static case of the dyna;ic case -> it's a small optimization.
scheduler :: Set.Set String -> [[ String ]] -> Map.Map (String, String) Conflict -> Set.Set String -> Map.Map String BoolExpr
scheduler allMsFpsRs priorityList confMatrix methodsEnabled = (\(x,y,z,t)->x) $ List.foldl
		(\acc1 elem -> List.foldl
					(\(acc2, mySet,previouslyScheduled,afterMethods) x ->
							let (myNewSet,newMeth) = addAfter x afterMethods mySet in
								if Set.member x mySet then 
									let previouslyConflicting = conflictWithBeforeSchedule acc2 x previouslyScheduled in
										(Map.insert 
											x 
											(bigAnd ((EDynGuard $ "RDY_" ++ x):previouslyConflicting))
											acc2
										, myNewSet
										, (x:previouslyScheduled)
										, newMeth)
								else (Map.insert x EFalse acc2
									, myNewSet
									, previouslyScheduled
									, newMeth))  --that I can trigger 
					acc1
					elem)
		(Map.empty, myInitSet methodsEnabled, [],allMsFpsRs)              --A kind of state monad, inline.
		priorityList
	where 
		myInitSet = Set.fold (\elem acc -> updateThePossibilities acc elem confMatrix) allMsFpsRs
		conflictWithBeforeSchedule acc2 x [] = []	
		conflictWithBeforeSchedule acc2 x (h:t) =  (case confMatrix Map.! (h,x) of
								CF -> []
								C -> [ENot $ acc2 Map.! h]
								SA -> []
								SB -> [ENot $ acc2 Map.! h])++
						(conflictWithBeforeSchedule acc2 x t) 	
		addAfter x meths set= if Set.member x methodsEnabled then (myInitSet meths, Set.delete x meths) else (set,meths)


updateThePossibilities :: Set.Set String -> String -> Map.Map (String,String) Conflict -> Set.Set String
updateThePossibilities possibilities nextMethod conflicts = Set.filter
		(\x -> case conflicts Map.! (nextMethod,x) of
				C -> False
				SA -> False
				SB -> True 
				CF -> True)
		possibilities



