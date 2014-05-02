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

import ATSProcessing
import TestParsers
import Debug.Trace


---
--- I love this stuff!
---

global :: Map.Map String Module
global = Map.empty


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


assembledBlocks :: [Module] -> [Map.Map (String,String) BoolExpr]
assembledBlocks [] = []  --The first half is done!
assembledBlocks (x:xs) = undefined 


conflictAndParameters :: String -> (Map.Map (String,String) [String], Map.Map ((String,String),(String, String)) Conflict)
conflictAndParameters m =
	let meths = Set.fromList . map (\x->("this", methodName x)) . methods $ global Map.! m
	in (Set.fold (\x acc1 -> Map.insert x (fpUsedByMethod actual fps' x m) acc1) Map.empty meths 
	   , undefined)
	where
		actual x = instArgs . head .filter (\n -> instName n == x ) . instances $ global Map.! m
		fps' x = fps $ global Map.! x   --Hacky name
{-  
conflictCalled :: (String -> [[ (String,String) ]]) -> 
		 [ Fp ] ->
		 Set.Set (String,String) -> 
		 Map.Map (String, String) Conflict ->
		 Map.Map (String,String) [String] ->
		 (String -> Map.Map ((String,String),(String,String)) Conflict) ->
	 Map.Map ((String,String),(String,String)) Conflict 

fpUsedByMethod :: (String -> [[ (String,String) ]]) -> 
		  (String -> [ Fp ]) ->
	  (String,String) -> String -> [String]

calcConflict :: Set.Set (String,String) -> 
		Set.Set (String,String) ->
		 Set.Set (String,String) ->
		((String,String) -> Set.Set ((String, String))) -> 
		Map.Map ((String, String), (String, String)) Conflict ->
		Map.Map (String,String) (String,String)
		-> Map.Map ((String,String),(String,String)) Conflict
-}	 



---
--- The three next functions are the core of the formal parameter thing.
---

-- I put the domains, the calles, the conflict matrix, the mapping of parameters to have the final conflict matrix
calcConflict :: Set.Set (String,String) -> Set.Set (String,String) -> Set.Set (String,String) ->
		((String,String) -> Set.Set ((String, String))) -> 
		Map.Map ((String, String), (String, String)) Conflict -> Map.Map (String,String) (String,String)
		-> Map.Map ((String,String),(String,String)) Conflict
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

-- The arguments of the next functions are the actual parameters of the submodulem the formal parameters of the submodule and this module, the current list of methods and the name of the module
fpUse :: (String -> [[ (String,String) ]]) -> (String-> [ Fp ]) -> [(String,String)] -> String -> [String]
fpUse actualFps fps (x:xs) mod = 
	let (modN,metN) = x 
	in if modN == "fp" && (List.elem metN $ map (\fp-> fpName fp) (fps $ mod)) 
		then metN:(fpUse actualFps fps xs mod)
		else fpUse actualFps fps (replace x ++xs) mod
	where 
		replace (a,b) = let l = fpUsedByMethod actualFps fps (a,b) a in
					toActualFp a l		 
		toActualFp m1 l = map (\x-> (correspondingFp m1) Map.! x) l
		correspondingFp m1 = Map.fromList . zip (map (\x -> fpName x) (fps $ mod  )) $ map head (actualFps m1) 

fpUsedByMethod :: (String -> [[ (String,String) ]]) -> (String-> [ Fp ]) ->  (String,String) -> String -> [String]
fpUsedByMethod actualFps fps meth mod =
	let env = buildEnv $ global Map.! mod 
	    calles = Set.elems $ methodsCalled env (head . List.filter (\x-> methodName x == snd meth ) . methods $ global Map.! mod) 
	in fpUse actualFps fps calles mod


--
--TODO : this function can be updated to a Fixpoint trick
--

conflictCalled :: (String -> [[ (String,String) ]]) -> [ Fp ] -> Set.Set (String,String) ->  Map.Map (String, String) Conflict -> Map.Map (String,String) [String] -> (String -> Map.Map ((String,String),(String,String)) Conflict) -> Map.Map ((String,String),(String,String)) Conflict 
conflictCalled actualFps fps calles conflictFp fpOfEachMethodInternally conflictOfEachPairInsideModule = --Do we want ((m,h),(m,h))? What is the conflict associated? 
	Set.fold
		(\(m1,h1) acc1 -> Set.fold
					(\(m2,h2) acc2 ->  Map.insert 
								((m1,h1),(m2,h2)) 
								(conflict ((m1,h1),(m2,h2)))
								acc2)
					acc1
					calles)
		Map.empty
		calles
	where 
		conflict ((m1,h1),(m2,h2)) | m1 == "fp" , m2 == "fp" = conflictFp Map.! (h1,h2) 
					   | m1 == m2 = (conflictOfEachPairInsideModule m1) Map.! (("this",h1),("this",h2))
					   | m1 == "fp" = let listFps2 = toActualFp m2 $ fpOfEachMethodInternally Map.! (m2,h2) in joins1 . map (\p-> conflict ((m1,h1),p)) $ listFps2
					   | m2 == "fp" = let listFps1 = toActualFp m1 $ fpOfEachMethodInternally Map.! (m1,h1) in joins1 . map (\p-> conflict (p,(m2,h2))) $ listFps1
					   | otherwise  = let listFps1 = toActualFp m1 $ fpOfEachMethodInternally Map.! (m1,h1)
					 	 	      listFps2 = toActualFp m2 $ fpOfEachMethodInternally Map.! (m2,h2)	
							      in joins1 . map (\(p,q) -> conflict (p,q))$ zip listFps1 listFps2  
		toActualFp m1 l = map (\x-> (correspondingFp m1) Map.! x) l
		correspondingFp mod = Map.fromList . zip (map (\x -> fpName x) fps) $ map head (actualFps mod)




--
--CORE of the scheduler
--

--
--V1 : The scheduler is combinatorial. I could schedule things with registers, it could be usefull.
-- Interests -> To have intermediate results.
--

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
		
	

--
--Tools for scheduling. TODO : Add bindings for that.
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

--
--Test case for the scheduler.
--

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



