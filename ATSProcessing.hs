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


type Env = Map.Map (String, String) Method

type MethodSet = Set.Set Method 

--

env :: Env
env = Map.empty 

methodCallMExpr :: Env -> MExpression -> Method
methodCallMExpr env expr = env Map.! (calledModule expr, calledMethod expr)  

expandOnOneMethod :: Env -> Method -> MethodSet
expandOnOneMethod env meth = Set.map (methodCallMExpr env) (Set.fromList $ methodBody meth)

expandOneTime :: Env -> MethodSet -> MethodSet
expandOneTime env smethods = (expandOnOneMethod env) =<< smethods

expandAll :: Env -> MethodSet -> MethodSet
expandAll env init = lfpFrom init (expandOneTime env) 
