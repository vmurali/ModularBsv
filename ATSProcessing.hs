module ATSProcessing where 
-- NEED lattices and set-monad
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
import Algebra.Lattice --Haskell <3
import TestParsers
import Text.Parsec hiding (token)
import Text.Parsec.String
import Text.Parsec.Prim

import Debug.Trace

instance Ord a => JoinSemiLattice (Set.Set a) where
	join = Set.union	

instance Ord a => BoundedJoinSemiLattice (Set.Set a) where
	bottom = Set.empty


type Env = Map.Map String Binding

type MethodSet = Set.Set Method 

--
--
--TODO TODO
--TODO TODO
--
--ADD THE SUPPORT OF THE RULES -> Normally it's easy.
--


buildEnv :: Module -> Env --We add the constants inside the env : it's easier, they are like leafs of a tree.
buildEnv m = List.foldl (\env bind -> addCstsInEnv bind env) (List.foldl (\env b -> Map.insert (bindName b) b env) Map.empty $ bindings m) $ bindings m
	where addCstsInEnv bind env = List.foldl
					(\locenv x -> if Map.member x locenv then locenv else Map.insert (x) 
													 (Binding {bindName = x
														, bindSize = 0 
														, bindExpr = SConst x}) 
													 locenv)
					env $
					case bindExpr bind of
						SConst a -> []
						Sext a ->  [a]
						Not a -> [a]
						BNot a ->  [a]
						Renaming a -> [a]
						Plus a b ->  [a,b]
						Times a b ->  [a,b]
						Divide a b ->  [a,b]
						Modulus a b ->  [a,b]
						Lt a b ->  [a,b]
						Gt a b  ->  [a,b]
						LtEq a b ->  [a,b]
						GtEq a b  ->  [a,b]
						ULt a b ->  [a,b]
						UGt a b ->  [a,b]
						PrimArrayDynSelect a b ->  [a,b]
						ULtEq a b ->  [a,b]
						UGtEq a b  ->  [a,b]
						BAnd a b ->  [a,b]
						BOr a b ->  [a,b]
						RShift a b  ->  [a,b]
						LShift a b ->  [a,b]
						BXor a b ->  [a,b]
						NotEqual a b ->  [a,b]
						Minus a b ->  [a,b]
						Equal a b ->  [a,b]
						R3Shift a b ->  [a,b]
						L3Shift a b ->  [a,b]
					 	Or a b ->  [a,b]
						And a b ->  [a,b]
						Mux a b c ->  [a,b,c]
						Extract a b c ->  [a,b,c]
						MCall _ -> []
						Concat l ->  l

				 
methodCalledMExpr :: Env -> MExpression -> Set.Set (String, String)   --I add all the methods called inside the if binding
methodCalledMExpr env expr = case calledCond expr of
	Nothing -> Set.singleton (calledModule expr, calledMethod expr)
	Just a ->  Set.singleton (calledModule expr, calledMethod expr) `Set.union` methodsCalledInBinding env (env Map.! a) 


methodsCalled :: Env -> Method -> Set.Set (String, String)
methodsCalled env m = Set.unions . map (methodCalledMExpr env) $ methodBody m

expandBindingToString :: Binding -> Set.Set String
expandBindingToString bind = Set.fromList $ (bindName bind : case bindExpr bind of
	 SConst a -> []
	 Sext a ->  [a]
	 Not a -> [a]
	 BNot a ->  [a]
	 Renaming a -> [a]
	 Plus a b ->  [a,b]
	 Times a b ->  [a,b]
	 Divide a b ->  [a,b]
	 Modulus a b ->  [a,b]
	 Lt a b ->  [a,b]
	 Gt a b  ->  [a,b]
	 LtEq a b ->  [a,b]
	 GtEq a b  ->  [a,b]
	 ULt a b ->  [a,b]
	 UGt a b ->  [a,b]
	 PrimArrayDynSelect a b ->  [a,b]
	 ULtEq a b ->  [a,b]
	 UGtEq a b  ->  [a,b]
	 BAnd a b ->  [a,b]
	 BOr a b ->  [a,b]
	 RShift a b  ->  [a,b]
	 LShift a b ->  [a,b]
	 BXor a b ->  [a,b]
	 NotEqual a b ->  [a,b]
	 Minus a b ->  [a,b]
	 Equal a b ->  [a,b]
	 R3Shift a b ->  [a,b]
	 L3Shift a b ->  [a,b]
 	 Or a b ->  [a,b]
	 And a b ->  [a,b]
	 Mux a b c ->  [a,b,c]
	 Extract a b c ->  [a,b,c]
	 MCall _ -> []
	 Concat l ->  l)


--Usefull tool	 
catMaybeOnSet :: Ord a => Set.Set (Maybe a) -> Set.Set a 
catMaybeOnSet = Set.fromList . Maybe.catMaybes . Set.elems   
--



expandBinding :: Env -> Binding -> Set.Set Binding
expandBinding env bind = Set.map (\x -> if Map.member x env 
						then env Map.! x
						else Binding {bindName = x
	, bindSize = 0 
	, bindExpr = SConst x})
				 (expandBindingToString bind)

expandBindings :: Env -> Set.Set Binding -> Set.Set Binding 
expandBindings env binds = (expandBinding env) =<< binds


expandUntilFp :: Env -> Set.Set Binding -> Set.Set Binding
expandUntilFp env init = lfpFrom init (expandBindings env) 

methodC :: Binding -> Maybe (String,String)
methodC bind = case bindExpr bind of
	MCall m -> Just (calledModule m, calledMethod m)
	_ -> Nothing  

methodsCalledInBinding :: Env -> Binding -> Set.Set (String,String)
methodsCalledInBinding env bind = catMaybeOnSet . Set.map methodC . expandUntilFp env $ Set.singleton bind


methodsCalledByMethod :: Env -> Method -> Set.Set (String, String)
methodsCalledByMethod env meth = case methodType meth of
	Value n -> methodsCalledInBinding env (env Map.! (methodName meth)) `Set.union` methodsCalledInBinding env (env Map.! ("RDY_" ++ methodName meth)) 
	Value0 n -> methodsCalledInBinding env (env Map.! (methodName meth)) `Set.union` methodsCalledInBinding env (env Map.! ("RDY_" ++ methodName meth)) 
	Action -> methodsCalledInBinding env (env Map.! ("RDY_" ++ methodName meth)) `Set.union`  methodsCalled env meth 
	ActionValue n -> methodsCalledInBinding env (env Map.! ("RDY_" ++ methodName meth)) `Set.union` 
			methodsCalledInBinding env (env Map.! (methodName meth)) `Set.union`
			methodsCalled env meth 


--type InstanceName = String
--type MethodName = String
--type RuleOrMethName = String
--type Condition = String
--type Argument = String
--methodsCalledRulesOrMethods :: Module -> Map RuleOrMethName {-->-} (Set.Set (InstanceName, MethodName))
--callerInformation :: Module -> Map (InstanceName, MethodName) {-->-} (Set.Set (Name, Condition, [Argument]))

--
--REVERSE THING : 
--
--a) the rule name or method name calling it
--b) the if condition predicate name at that point
--c) the arguments with which the method is called at that point
--
--

--Two cases for a ) 
--   - the method called is called in the body of a rule/method -> Easy to have the caller.
--   - the method called is called under a ton of bindings -> We have to fold the bindings until a bindname match with a methodname. 
--   		-> Is it correct? Any distinction between different types of methods?
--
--b) What do you mean? The last if statement conditionning that trigger this call?
--



--
--TODO RULES
--

--
--TODO : If you prefer a map, we can build the map the fromSet function
--

-- 
--TODO : LIFT THE NAMES AND THE ORDER OF THE ARGUMENTS OF MY FUNCTIONS 
--	



-- We use [[ String ]] but actually it cannot contains more than one element. TODO : Another datastructure ? -> Dunno, great haskell backend for lists 

callerInformation :: Module -> Env -> (String, String) -> [ (String, Maybe String, [String])] --Why the Set datastructure? Perf? Think about that. TODO
callerInformation mod env names = 
	Maybe.catMaybes . map (\method -> let called = argsMethodCallInsideMethod env names method in
						case called of
							[] -> Nothing
							[a] ->let theCond = catchTheCond env names method in
								case theCond of 
									[] -> Just (methodName method, Nothing, a)
									[b] -> Just (methodName method, Just b, a) 
									_ -> trace "False assumption l 182" $ undefined 
							_ -> undefined ) $ methods mod

catchTheCond :: Env -> (String, String) -> Method -> [String]
catchTheCond env names method = (Maybe.catMaybes . map (extractCondFromMExpr env names) $ methodBody method)
						++ Set.elems (extractCondFromBind env names (Set.empty) (env Map.! ("RDY_" ++ methodName method)))
						++ case methodType method of
							Action -> []
							_ -> Set.elems (extractCondFromBind env names (Set.empty) (env Map.! methodName method))

extractCondFromMExpr :: Env -> (String, String) -> MExpression ->  Maybe String  --I assume our hypothesis here. BIG ISSUE if it's false.
extractCondFromMExpr env (nMod, nMet) expr = case calledCond expr of
	Nothing -> Nothing
	Just a ->  if (nMod, nMet) == (calledModule expr ,calledMethod expr) then Just a else Nothing

 
extractCondFromBind :: Env -> (String, String) -> Set.Set String -> Binding ->  Set.Set String   --Fucking greedy. 
extractCondFromBind env names path bind = case bindExpr bind of
	 MCall m -> if names == (calledModule m, calledMethod m) then path else Set.empty
	 Mux a b c -> Set.unions . map (extractCondFromBind env names (Set.insert a path)) $ [ env Map.! b, env Map.! c]
	 _ -> Set.unions . map ((extractCondFromBind env names path) . ((env Map.!)))$ case bindExpr bind of 
		 SConst a -> []
		 Sext a ->  [a]
		 Not a -> [a]
		 BNot a ->  [a]
		 Renaming a -> [a]
		 Plus a b ->  [a,b]
		 Times a b ->  [a,b]
		 Divide a b ->  [a,b]
		 Modulus a b ->  [a,b]
		 Lt a b ->  [a,b]
		 Gt a b  ->  [a,b]
		 LtEq a b ->  [a,b]
		 GtEq a b  ->  [a,b]
		 ULt a b ->  [a,b]
		 UGt a b ->  [a,b]
		 PrimArrayDynSelect a b ->  [a,b]
		 ULtEq a b ->  [a,b]
		 UGtEq a b  ->  [a,b]
		 BAnd a b ->  [a,b]
		 BOr a b ->  [a,b]
		 RShift a b  ->  [a,b]
		 LShift a b ->  [a,b]
		 BXor a b ->  [a,b]
		 NotEqual a b ->  [a,b]
		 Minus a b ->  [a,b]
		 Equal a b ->  [a,b]
		 R3Shift a b ->  [a,b]
		 L3Shift a b ->  [a,b]
 		 Or a b ->  [a,b]
		 And a b ->  [a,b]
		 Extract a b c ->  [a,b,c]
		 Concat l ->  l
	   

argsMethodCallInsideMethod :: Env -> (String, String) -> Method -> [[ String ]] -- The list contains at most one sublist
argsMethodCallInsideMethod env names meth =  (concat . map (argsMethodCallInsideMExpr env names) $ methodBody meth) ++ --Perhaps inside the body
	(argsMethodCallInsideBinding env names  $ env Map.! ("RDY_" ++ methodName meth)) ++  --Perhaps It's called inside the ready statement
 	case methodType meth of  -- Or inside the result
		Value n -> argsMethodCallInsideBinding env names  $ env Map.! methodName meth
		Value0 n -> argsMethodCallInsideBinding env names $ env Map.! methodName meth
		Action -> []
		ActionValue n -> argsMethodCallInsideBinding env names $ env Map.! methodName meth


argsMethodCallInsideMExpr :: Env -> (String, String) -> MExpression -> [[ String ]]
argsMethodCallInsideMExpr env names expr = (if (calledModule expr,calledMethod expr) == names then [calledArgs expr] else []) ++ 
 	case calledCond expr of
		Nothing -> []
		Just a -> argsMethodCallInsideBinding env names (env Map.! a)


argsMethodCallInsideBinding :: Env -> (String, String) -> Binding -> [[ String ]]
argsMethodCallInsideBinding env (nMod,nMet) bind = case (bindExpr bind) of
	MCall m -> if (calledModule m,calledMethod m) == (nMod, nMet) then [ calledArgs m ] else []
	_ -> concat . map (argsMethodCallInsideBinding env (nMod,nMet) . ( env Map.!)) $
		case bindExpr bind of 
			SConst a -> []
			Sext a -> [ a]
			Not a -> [ a]
			BNot a -> [ a]
			Renaming a -> [a]
			Plus a b -> [ a,b]
			Times a b -> [ a,b]
			Divide a b -> [ a,b]
			Modulus a b -> [ a,b]
			Lt a b -> [ a,b]
			Gt a b  -> [ a,b]
			LtEq a b -> [ a,b]
			GtEq a b  -> [ a,b]
			ULt a b -> [ a,b]
			UGt a b -> [ a,b]
			PrimArrayDynSelect a b -> [ a,b]
			ULtEq a b -> [ a,b]
			UGtEq a b  -> [ a,b]
			BAnd a b -> [ a,b]
			BOr a b -> [ a,b]
			RShift a b  -> [ a,b]
			LShift a b -> [ a,b]
			BXor a b -> [ a,b]
			NotEqual a b -> [ a,b]
			Minus a b -> [ a,b]
			Equal a b -> [ a,b]
			R3Shift a b -> [ a,b]
			L3Shift a b -> [ a,b]
 			Or a b -> [ a,b]
			And a b -> [ a,b]
			Mux a b c -> [ a,b,c]
			Extract a b c -> [ a,b,c]
	 		Concat l -> l



main :: IO()
main = do
	parse <- parseFromFile modulesParser "DumpProc.hs"
	case parse of
		Left _ -> undefined
		Right lmodule -> let poulpe = head . drop 8 $ lmodule in  
				 let env = buildEnv poulpe in
				 print . show . callerInformation poulpe env $ ("copFifo_enqEn_dummy2_0","read") 
			

			-- methodsCalledByMethod env . head . drop 1 $ methods poulpe 
			
			--	 print . show $ methods poulpe 	
			-- 	 let monbindprefere = env Map.! "RDY_wr" in --"x__h3447" in
			--		 print . show . methodsCalledByMethod env $ monbindprefere

