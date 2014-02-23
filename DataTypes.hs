module DataTypes where

import Data.Map

type Expr = String
type WireName = String
type WireWidth = Integer

type Wire = (WireName, WireWidth)

data Who = Rule | Method
  deriving (Show, Read, Eq)

data Binding = Binding
  { wire :: Wire
  , who :: Who
  , expr :: Expr
  } deriving (Show, Read, Eq)

type ResWidth = Integer

data MethType = Action | Value ResWidth | Value0 ResWidth | ActionValue ResWidth
  deriving (Show, Read, Eq)

type MethName = String

data CM = C | LT | GT | CF
  deriving (Show, Read, Eq)

type ModName = String
type RuleName = String
type MethArg = String
type InstName = String
type FullCallMeth = (InstName, MethName)

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

data CompiledMod = CompiledMod
  { compName :: ModName
  , compFps :: [MethName]
  , compFpTypes :: Map MethName (MethType, [MethArg])
  , compCmFP :: Map (MethName, MethName) CM
  , compCmDm :: Map (MethName, MethName) CM
  , compFpu :: Map MethName [MethName]
  } deriving (Show, Read, Eq)

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
