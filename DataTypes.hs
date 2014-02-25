module DataTypes where

import Data.Map

-- An expression never changes, so I can treat it as a string
type Expr = String

-- A wire contains a name and a width
type WireName = String
type WireWidth = Integer

type Wire = (WireName, WireWidth)

-- A binding contains a wire (name+width), an expression, and a boolean saying if
-- the wire is a temporary variable or the ready signal of a rule.
-- If it belongs to a rule (ie a temporary variable defined by a rule or the
-- ready signal of a rule, then it will use _sch instead of _rdy
data Binding = Binding
  { wire :: Wire
  , isRule :: Bool
  , expr :: Expr
  } deriving (Show, Read, Eq)


-- A method type is Action/Value/Value0/ActionValue. The ResWidth indicates
-- the bitwidth of the result if it is not an action
type ResWidth = Integer

data MethType = Action | Value ResWidth | Value0 ResWidth | ActionValue ResWidth
  deriving (Show, Read, Eq)

type MethName = String

-- Conflict Matrix values: C = {}, SB = {<}, SA = {>}, CF = {<, >}
data CM = C | SB | SA | CF
  deriving (Show, Read, Eq)

type ModName = String
type RuleName = String
type MethArg = String
type InstName = String
type FullCallMeth = (InstName, MethName)

-- This is the main data structure that I need
-- It contains:
-- a) module name
-- b) formal parameter (fp) names
-- c) mapping from fp to (fp's Method type, [fp's Method arguments])
-- d) CM_FP - the CM relation between every pair of fp's. (This is currently
--          not supplied by Bluespec, so I will have to either assume CF or C
--          by default. I think I will start with CF.
-- e) Mapping from Instance name to (module name and actual parameters supplied to module)
--          each actual parameter contains a (instance name, method name) tuple
--          An actual parameter of an instance can be a formal parameter of the current
--          module. In this case, the instance name is an empty string. This tuple is
--          called FullCallMeth
-- f) Binding list containing every single binding in the module. Using this,
--          there is no need to look at any rule body or method body. This is essentially
--          one step away from verilog netlist (scheduling phase is left)
-- g) list of rule names
-- h) mcalls: a mapping from (rule or defined method name) to list of FullCallMeth, which
--          represents all the methods called by the rule or the defined method
-- i) a mapping from a defined method name to its method type and the list of arguments
data Module = Module
  { modName :: ModName
  , fps :: [MethName]
  , fpTypes :: Map MethName (MethType, [MethArg])
  , cmFP :: Map (MethName, MethName) CM
  , insts :: Map InstName (ModName, [FullCallMeth])
  , bindings :: [Binding]
  , rules :: [RuleName]
  , mcalls :: Map String [FullCallMeth]
  , defMeths :: Map MethName (MethType, [MethArg])
  } deriving (Show, Read, Eq)


----------- Anything above this is fixed and most likely not subject to future changes

-- Each compiled module produces this data structure. This could be enhanced if necessary
data CompiledMod = CompiledMod
  { compName :: ModName
  , compFps :: [MethName]
  , compFpTypes :: Map MethName (MethType, [MethArg])
  , compCmFP :: Map (MethName, MethName) CM
  , compCmDm :: Map (MethName, MethName) CM
  , compFpu :: Map MethName [MethName]
  } deriving (Show, Read, Eq)


-- This pertains to creating a verilog netlist. Again, this is subject to change.
type PortName = String
data PortType = Input | Output | Wire
  deriving (Show, Read, Eq)

type PortWidth = Integer
data Port = Port
  { pName :: PortName
  , pType :: PortType
  , pWidth :: PortWidth
  } deriving (Show, Read, Eq)

data NInst = NInst
  { niName :: InstName
  , niMod :: ModName
  , niBinds :: [(MethName, FullCallMeth)]
  } deriving (Show, Read, Eq)

data Netlist = Netlist
  { ports :: [Port]
  , assigns :: [(PortName, Expr)]
  , nInsts :: [NInst]
  } deriving (Show, Read, Eq)
