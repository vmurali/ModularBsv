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
calcConflict :: Set.Set (String,String) -> Set.Set (String,String) -> Set.Set (String,String) -> ((String,String) -> Set.Set ((String, String))) -> Map.Map ((String, String), (String, String)) Conflict -> Map.Map (String,String) (String,String) -> Map.Map ((String,String),(String,String)) Conflict
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

conflictCalled :: Set.Set (String,String) ->  Map.Map (String, String) Conflict -> Map.Map (String,String) [String] -> (String -> Map.Map ((String,String),(String,String)) Conflict) -> Map.Map ((String,String),(String,String)) Conflict 
conflictCalled  calles conflictFp fpOfEachMethodInternally conflictOfEachPairInsideModule = --Do we want ((m,h),(m,h))? What is the conflict associated? 
	Set.fold
		(\(m1,h1) acc1 -> Set.fold
					(\(m2,h2) acc2 ->  Map.insert ((m1,h1),(m2,h2)) (conflict ((m1,h1),(m2,h2))) acc2)
					acc1
					calles)
		Map.empty
		calles
	where conflict ((m1,h1),(m2,h2)) | m1 == "fp" , m2 == "fp" = conflictFp Map.! (h1,h2) 
					 | m1 == m2 = (conflictOfEachPairInsideModule m1) Map.! (("this",h1),("this",h2))
					 | m1 == "fp" = let listFps2 = undefined in joins1 . map (\p-> conflict ((m1,h1),p)) $ listFps2
					 | m2 == "fp" = let listFps1 = undefined in joins1 . map (\p-> conflict (p,(m2,h2))) $ listFps1
					 | otherwise = let listFps1 = undefined--fpOfEachMethodInternally (h1,m1)
					 	 	   listFps2 = undefined--fpOfEachMethodInternally (h2,m2)	
							   in joins1 . map (\(p,q) -> conflict (p,q))$ zip listFps1 listFps2  


--
--CORE of the scheduler
--

data BoolExpr =  ETrue
	| EFalse 
	| EAnd [BoolExpr]
	| ENot  BoolExpr
	| EDynGuard String
	deriving(Show,Eq,Ord)

simplifyCircuitAnd :: BoolExpr ->  BoolExpr
simplifyCircuitAnd x = case x of
	EAnd l -> if List.elem EFalse l 
			then EFalse
			else case List.filter (\x -> x/= ETrue) l of
				[] -> ETrue
				l' -> EAnd l'
			 
	_ -> x


testMs = Set.fromList [ "m_1"
				
		] 

testRs = Set.fromList ["r_1"
		]

testFps = Set.fromList [ "fp_1"
		]

testPl = [["m_1"],["r_1"],["fp_1"]]

testConfMatrix = Map.fromList [(("fp_1"   ,"fp_1"), CF)
				, (("fp_1","r_1" ),  SA )
				, (("fp_1","m_1" ), CF )
				, (("r_1","fp_1"), SB ) 
				, (("r_1","r_1"),  CF )
				, (("r_1","m_1"), C )
				, (("m_1","fp_1"), CF )
				, (("m_1","r_1" ), C )
				, (("m_1","m_1" ), CF )
				]


-- In the scheduler, I distinguish the static case of the dyna;ic case -> it's a small optimization.
scheduler :: Set.Set (String,String) -> Set.Set (String,String) -> Set.Set (String,String) -> [[ (String,String) ]] -> Map.Map ((String,String),(String,String)) Conflict ->  Map.Map (String,String) BoolExpr
scheduler ms rs fps priorityList confMatrix = Map.map simplifyCircuitAnd .(\(x,y,z,t,u)->x) $ List.foldl
		(\acc1 elem -> List.foldl
					(\(acc2, beforeMethods,beforeFp, beforeR, afterMethods) x ->
						if Set.member x ms then  --A method
							let nAfterMethods = List.delete x afterMethods in
								(Map.insert x (EAnd $ 
									[EDynGuard $ "EN_" ++ snd x] 
									) acc2
								, x:beforeMethods, beforeFp , beforeR, nAfterMethods)
						else if Set.member x rs 
							then (Map.insert x --TODO
									(EAnd $[EDynGuard $ "RDY_" ++ snd x ] ++bM x beforeMethods ++ bF x beforeFp ++ bR x beforeR ++ aM x afterMethods )
									acc2
								, beforeMethods, beforeFp, x:beforeR, afterMethods)	--A rule
							else  (Map.insert x
									(EAnd $ bM x beforeMethods ++ bF x beforeFp ++ bR x beforeR ++ aM x afterMethods)
									acc2
								, beforeMethods, x:beforeFp, beforeR, afterMethods))			-- A fp
					acc1
					elem)
		(Map.empty, [], [], [], Set.elems ms)
		priorityList
	where 	bM x [] = []
		bM x (h:t) = (case confMatrix Map.! (h,x) of 
				CF -> ETrue
				C  -> (ENot . EDynGuard $ "EN_" ++ snd h)
				SB -> ETrue
				SA -> (ENot . EDynGuard $ "EN_" ++ snd h)):(bM x t) 
                
                bF x [] = []
		bF x (h:t) = (case confMatrix Map.! (h,x) of 
				CF -> ETrue
				C  -> EFalse
				SB -> ETrue
				SA -> EFalse):(bF x t) 
                bR x [] = []
                bR x (h:t) = (case confMatrix Map.! (h,x) of 
				CF -> ETrue
				C  -> (ENot . EDynGuard $ "EN_" ++ snd h)
				SB -> ETrue
				SA -> (ENot . EDynGuard $ "EN_" ++ snd h)):(bR x t) 
                aM x [] = []
                aM x (h:t) = (case confMatrix Map.! (x,h) of 
				CF -> ETrue
				C  -> (ENot . EDynGuard $ "EN_" ++ snd h)
				SB -> ETrue
				SA -> (ENot . EDynGuard $ "EN_" ++ snd h)):(aM x t) 
		
	
--updateThePossibilities :: Set.Set String -> String -> Map.Map (String,String) Conflict -> Set.Set String
--updateThePossibilities possibilities nextMethod conflicts = Set.filter
--		(\x -> case conflicts Map.! (nextMethod,x) of
--				C -> False
--				SA -> False
--				SB -> True 
--				CF -> True)
--		possibilities
--




