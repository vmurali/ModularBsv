module ModuleNetlist where

import DataTypes

getModuleNetlist :: [CompiledMod] -> Module -> Netlist
getModuleNetlist cms (Module modName fps fpTypes cmFP insts bindings rules mcalls defMeths) =
  undefined
