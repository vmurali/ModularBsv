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
import Algebra.Lattice --Haskell :3
import TestParsers

instance Ord a => JoinSemiLattice (Set.Set a) where
	join = Set.union	

instance Ord a => BoundedJoinSemiLattice (Set.Set a) where
	bottom = Set.empty


type Env = Map.Map String Binding

type MethodSet = Set.Set Method 

--

env :: Env
env = Map.empty 

methodCalledMExpr :: MExpression -> (String, String) 
methodCalledMExpr expr = (calledModule expr, calledMethod expr)

methodsCalled :: Method -> [ (String, String) ]
methodsCalled m = map methodCalledMExpr $ methodBody m

expandBindingToString :: Binding -> Set.Set String
expandBindingToString bind = case bindExpr bind of
	 Sext a -> Set.fromList [a]
	 Not a -> Set.fromList [a]
	 BNot a -> Set.fromList [a]
	 Renaming a -> Set.fromList [a]
	 Plus a b -> Set.fromList [a,b]
	 Times a b -> Set.fromList [a,b]
	 Divide a b -> Set.fromList [a,b]
	 Modulus a b -> Set.fromList [a,b]
	 Lt a b -> Set.fromList [a,b]
	 Gt a b  -> Set.fromList [a,b]
	 LtEq a b -> Set.fromList [a,b]
	 GtEq a b  -> Set.fromList [a,b]
	 ULt a b -> Set.fromList [a,b]
	 UGt a b -> Set.fromList [a,b]
	 PrimArrayDynSelect a b  -> Set.fromList [a,b]
	 ULtEq a b -> Set.fromList [a,b]
	 UGtEq a b  -> Set.fromList [a,b]
	 BAnd a b -> Set.fromList [a,b]
	 BOr a b -> Set.fromList [a,b]
	 RShift a b  -> Set.fromList [a,b]
	 LShift a b -> Set.fromList [a,b]
	 BXor a b -> Set.fromList [a,b]
	 NotEqual a b -> Set.fromList [a,b]
	 Minus a b -> Set.fromList [a,b]
	 Equal a b -> Set.fromList [a,b]
	 R3Shift a b -> Set.fromList [a,b]
	 L3Shift a b -> Set.fromList [a,b]
 	 Or a b -> Set.fromList [a,b]
	 And a b -> Set.fromList [a,b]
	 Mux a b c -> Set.fromList [a,b,c]
	 Extract a b c -> Set.fromList [a,b,c]
	 MCall _ -> Set.empty
	 Concat l -> Set.fromList l
	 	
expandBinding :: Env -> Binding -> Set.Set Binding
expandBinding env bind = Set.fromList . Maybe.catMaybes . Set.elems $ Set.map (\x -> Map.lookup x env) (expandBindingToString bind)

expandBindings :: Env -> Set.Set Binding -> Set.Set Binding 
expandBindings env binds = (expandBinding env) =<< binds


expandUntilFp :: Env -> Set.Set Binding -> Set.Set Binding
expandUntilFp env init = lfpFrom init (expandBindings env) 


