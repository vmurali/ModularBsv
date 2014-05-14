module DataTypes where

import qualified Data.Map as Map

type ThisName = String
type CalledMethod = (String, String)

type DefinedMethod = String
type InstName = String
type ModuleName = String
type FpName = String

data Conflict =  C | CF | SB | SA deriving(Show,Eq,Ord)

{-
data Op
  = None
  | Unary String
  | Binary String
  | Word String
  | MethCall CalledMethod
  deriving (Show, Eq, Ord)

data Expr = Expr Op [String] deriving (Show, Eq, Ord)

data Binding = Binding
  { bindName :: String
  , bindArray :: Maybe Integer
  , bindSize :: Integer 
  , bindExpr :: Expr
  } deriving(Show,Eq,Ord)--Done

data Calleds = Calleds
  { calledCond :: String 
  , calledMethod :: CalledMethod
  , calledArgs :: [ ArgName ]
} deriving(Show,Eq,Ord)--Done 

type ArgName = String

data Rule = Rule
  { ruleGuard :: String 
  , ruleBody :: [ Calleds ]
  } deriving(Show,Eq,Ord)--Done

type RuleName = String

data Module = Module
  { moduleName :: ModuleName
  , instances :: Map.Map InstName Instance
  , bindings :: [ Binding ]
  , rules :: Map.Map RuleName Rule
  , methods :: Map.Map DefinedMethod Method
  , fps :: [ Fp ]
  , fpConflict :: Map.Map (FpName, FpName) Conflict 
  , priorityList :: [ [ CalledMethod ] ]
  } deriving(Show,Eq,Ord)--Done

data Instance = Instance
  { instModule :: ModuleName
  , instArgs :: [[ (String,String) ]] --hacky
  } deriving(Show,Eq,Ord)--Done

data Method = Method 
  { methodType :: TypeOfMethod  
  , methodArgs :: [(ArgName, Integer)]
  , methodBody :: [ Calleds ]
  } deriving(Show,Eq,Ord) --Done

data Fp = Fp
  { fpType :: TypeOfMethod
  , fpArgs :: [ (ArgName,Integer) ]
} deriving(Show,Eq,Ord)

-- Unit operations in the body of a method.
data Calleds = Calleds {calledCond :: Maybe String 
  , calledMethod :: CalledMethod
  , calledArgs :: [ ArgName ]
} deriving(Show,Eq,Ord)--Done 


--The integers are the size of the result
data TypeOfMethod
  = Value Integer  
  | Value0 Integer
  | Action
  | ActionValue Integer
  deriving(Show,Eq,Ord)

data ModuleIfc = ModuleIfc
  { fpsInModule :: [FpName]
  , fpsForMethodInModule :: Map.Map DefinedMethod [FpName] 
  , cmForMethodsInModule :: Map.Map (DefinedMethod, DefinedMethod) Conflict
  } deriving (Show,Eq,Ord)

type ModuleIfcs = Map.Map String ModuleIfc

-}
