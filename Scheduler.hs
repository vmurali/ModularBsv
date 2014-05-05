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




data PData = PData {fpNames :: [String]
			, actualParametersForEachInst :: Map.Map String [String] 
			, cM :: Map.Map ((String,String),(String,String)) Conflict }

type PDatas = Map.Map String PData  --Data exported by each module compiled


compileAModule :: Module -> PDatas -> PDatas --This function add the information of compilation into the environnement of type PDatas
compileAModule currentModule publicData =
	let meths  = Set.fromList . map (\x->("this", methodName x)) . methods $ currentModule 
 	    rs     = Set.fromList . map (\x->("this", ruleName x)) . rules $ currentModule
 	    fpsLoc = Set.fromList . map (\x->("this", fpName x)) . fps $ currentModule
	    env = buildEnv currentModule 
	in Map.insert 
		(name currentModule)
		PData {fpNames = map (\x -> fpName x) $ fps currentModule   
		      , actualParametersForEachInst = List.foldl
							(\acc x -> Map.insert (methodName x) 
									      (map snd . filter (\(a,b)-> a=="fp" ). Set.elems . methodsCalled env $ x)
									      acc)
							Map.empty
							$ methods currentModule   
		      , cM = calcConflict 
				rs
				meths
				fpsLoc
				(methodsCalled env . (\x -> head . filter (\y -> ("this",methodName y) == x) $ methods currentModule))
				$ conflictCalled 
					(\x->  map (\under -> head under) . instArgs . head . filter (\i -> instName i == x) . instances $ currentModule)						
					(fps currentModule)
					(Set.union fpsLoc meths)
					(conflictMatrix currentModule)
					(Set.fold (\elem acc -> Map.insert elem (fpUsedByMethod (\x y -> (actualParametersForEachInst $ publicData Map.! x) Map.! y )
							      		(\x -> fpNames $ publicData Map.! x )
							      		elem --methodname
							      		currentModule) acc) Map.empty meths)
					(\x -> cM $ publicData Map.! x)}
		publicData	



 
calcConflict :: Set.Set (String,String) ->   --Set of rules
		Set.Set (String,String) ->   --Set of defined methods
		Set.Set (String,String) ->   --Set of formal parameters
		((String,String) -> Set.Set ((String, String))) ->	--Calles function (It's a local thing to the module)
		Map.Map ((String, String), (String, String)) Conflict   --confMatrix, output of the conflictCalled function
		-> Map.Map ((String,String),(String,String)) Conflict   --conflict matrix on defined methods
calcConflict rs ms fps calles confMatrix = 
	let union = Set.unions [rs, ms, fps] in
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



---
--- This code has been a little been factorized.
---

-- The arguments of the next functions are the actual parameters of the submodulem the formal parameters of the submodule and this module, the current list of methods and the name of the module
fpUse :: (String -> String -> [ String ]) -> (String-> [ String ]) -> [(String,String)] -> Module -> [String]
fpUse actualFps allFps (x:xs) mod = 
	let (modN,metN) = x 
	in if modN == "fp" && (List.elem metN . allFps . name $ mod  ) 
		then metN:(fpUse actualFps allFps xs mod)
		else fpUse actualFps allFps (replace x ++ xs) mod
	where
		replace (a,b) = let l = actualFps a b in
					toActualFp a l	 
		toActualFp m1 l = map (\x-> (correspondingFp m1) Map.! x) l
		correspondingFp m1 = Map.fromList . zip (allFps m1) . head . instArgs . head . filter (\x->instName x == m1) . instances $ mod --hacky head 

fpUsedByMethod :: (String -> String -> [ String ]) -> (String-> [ String ]) ->  (String,String) -> Module -> [String]
fpUsedByMethod actualFps allFps meth mod =
	let env    = buildEnv mod 
	    calles = Set.elems $ methodsCalled env (head . List.filter (\x-> methodName x == snd meth ) . methods $ mod) 
	in fpUse actualFps allFps calles mod


--
--TODO : this function can be updated to a Fixpoint trick
--

conflictCalled :: (String -> [(String,String)]) --actual fps instances -> list of methods 
		-> [ Fp ]  --fps
		-> Set.Set (String,String)    --Methods called
		->  Map.Map (String, String) Conflict --conflict between FPs
		-> Map.Map (String,String) [String] -> -- fp of each method internally
		 (String -> Map.Map ((String,String),(String,String)) Conflict) -- conflict inside instances
		-> Map.Map ((String,String),(String,String)) Conflict 
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
		-- Todo : Check this piece of code
		toActualFp m1 l = map (\x-> (correspondingFp m1) Map.! x) l
		correspondingFp mod = Map.fromList . zip (map (\x -> fpName x) fps) $ actualFps mod




--
--CORE of the scheduler
--

--
--V1 : The scheduler is combinatorial. I could schedule things with registers, it could be usefull.
-- Interests -> To have intermediate results.
--

scheduler :: Set.Set (String,String) -> --Set of defined methods
	     Set.Set (String,String) -> --Set of rules
	     Set.Set (String,String) -> --Set of formal parameters
	     [[ (String,String) ]] -> --Priority List 
	     Map.Map ((String,String),(String,String)) Conflict -> --Conflict matrix provided by the calcConflict function?
	     Map.Map (String,String) BoolExpr   --Combinatorial scheduler
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

testMs = Set.fromList [( "this","m_1")
				
		] 

testRs = Set.fromList [("this","r_1")
		]

testFps = Set.fromList [ ("this","fp_1")
		]

testPl = [[("this","m_1")],[("this","r_1")],[("this","fp_1")]]

testConfMatrix = Map.fromList [((("this","fp_1")   ,("this","fp_1")), CF)
				, ((("this","fp_1"),("this","r_1" )),  SA )
				, ((("this","fp_1"),("this","m_1" )), CF )
				, ((("this","r_1"),("this","fp_1")), SB ) 
				, ((("this","r_1"),("this","r_1")),  CF )
				, ((("this","r_1"),("this","m_1")), C )
				, ((("this","m_1"),("this","fp_1")), CF )
				, ((("this","m_1"),("this","r_1" )), C )
				, ((("this","m_1"),("this","m_1" )), CF )
				]



