module DataTypes where
import Debug.Trace
import qualified Data.Map as Map

traceStr y x = trace (y ++ show x) x

type ThisName = String
type CalledMethod = (String, String)

type DefinedMethod = String
type InstName = String
type ModuleName = String
type FpName = String

data Conflict =  C | CF | SB | SA deriving(Show,Eq,Ord)

data Op
  = None
  | Unary String
  | Binary String
  | Word String
  | Rdy CalledMethod
  | MethCall CalledMethod
  deriving (Show, Eq, Ord)

data Expr = Expr Op [String] deriving (Show, Eq, Ord)

data Binding = Binding
  { bindArray :: Maybe Integer
  , bindSize :: Integer 
  , bindExpr :: Expr
  } deriving(Show, Eq,Ord)--Done

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

--The integers are the size of the result
data TypeOfMethod
  = Value Integer  
  | Action
  | ActionValue Integer
  deriving(Show,Eq,Ord)

data Method = Method 
  { methodType :: TypeOfMethod  
  , methodArgs :: [(ArgName, Integer)]
  , methodBody :: [ Calleds ]
  } deriving(Show,Eq,Ord) --Done

data Fp = Fp
  { fpName :: FpName
  , fpType :: TypeOfMethod
  , fpArgs :: [ (ArgName,Integer) ]
} deriving(Show,Eq,Ord)

data Inst = Inst
  { instModule :: ModuleName
  , instWidth :: Expr
  , instInit :: Expr
  , instSize :: Expr
  , instArgs :: [CalledMethod]
  } deriving(Show,Eq,Ord)

type RuleName = String

type BindName = String

type PriorityElem = (String, String)

data Module = Module
  { moduleName :: ModuleName
  , instances :: Map.Map InstName Inst
  , bindings :: Map.Map BindName Binding
  , rules :: Map.Map RuleName Rule
  , methods :: Map.Map DefinedMethod Method
  , fps :: [Fp]
  , fpConflict :: Map.Map (FpName, FpName) Conflict 
  , priorityList :: [ [ PriorityElem ] ]
  } deriving(Show,Eq,Ord)--Done

data ModuleIfc = ModuleIfc
  { fpsInModule :: [Fp]
  , methodsInModule :: Map.Map DefinedMethod (TypeOfMethod, [(ArgName, Integer)], [FpName])
  , cmForMethodsInModule :: Map.Map (DefinedMethod, DefinedMethod) Conflict
  } deriving (Show,Eq,Ord)

type ModuleIfcs = Map.Map String ModuleIfc
