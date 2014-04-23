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

instance Ord a => JoinSemiLattice (Set.Set a) where
	join = Set.union	

instance Ord a => BoundedJoinSemiLattice (Set.Set a) where
	bottom = Set.empty


type Env = Map.Map String Binding

type MethodSet = Set.Set Method 

--


buildEnv :: Module -> Env
buildEnv m = List.foldl (\env b -> Map.insert (bindName b) b env) Map.empty $ bindings m

methodCalledMExpr :: MExpression -> (String, String) 
methodCalledMExpr expr = (calledModule expr, calledMethod expr)

methodsCalled :: Method -> Set.Set (String, String)
methodsCalled m = Set.fromList . map methodCalledMExpr $ methodBody m

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
	Action -> methodsCalledInBinding env (env Map.! ("RDY_" ++ methodName meth)) `Set.union`  methodsCalled meth 
	ActionValue n -> methodsCalledInBinding env (env Map.! ("RDY_" ++ methodName meth)) `Set.union` 
			methodsCalledInBinding env (env Map.! (methodName meth)) `Set.union`
			methodsCalled meth 

type InstanceName = String
type MethodName = String
type RuleOrMethName = String
type Condition = String
type Argument = String
methodsCalledRulesOrMethods :: Module -> Map RuleOrMethName {-->-} (Set.Set (InstanceName, MethodName))
callerInformation :: Module -> Map (InstanceName, MethodName) {-->-} (Set.Set (Name, Condition, [Argument]))

--
--REVERSE THING : 
--
--a) the rule name or method name calling it
--b) the if condition predicate name at that point
--c) the arguments with which the method is called at that point
--
--

main :: IO()
main = do
	parse <- parseFromFile modulesParser "DumpProc.hs"
	case parse of
		Left _ -> undefined
		Right lmodule -> let poulpe = head . drop 8 $ lmodule in  
				 let env = buildEnv poulpe in
				 print . show . methodsCalledByMethod env . head . drop 1 $ methods poulpe 
			
			--	 print . show $ methods poulpe 	
			-- 	 let monbindprefere = env Map.! "RDY_wr" in --"x__h3447" in
			--		 print . show . methodsCalledByMethod env $ monbindprefere

