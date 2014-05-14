module CompiledMod where

import DataTypes

getCompiledMod :: [CompiledMod] -> Module -> CompiledMod
getCompiledMod cms (Module modName fps fpTypes cmFP insts bindings rules mcalls defMeths) =
  undefined
