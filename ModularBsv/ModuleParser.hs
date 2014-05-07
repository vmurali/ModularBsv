module ModuleParser where

import Text.Parsec
import Lexer
import DataTypes
import ExprParser
import RuleParser
import InstanceParser
import CommentsParser
import MethodParser
import Data.Map

moduleParser = do
  symbol "=== ATS:"
  symbol "APackage"
  modName <- identifier
  symbol "-- AP state elements"
  symbol "[]"
  insts' <- many instanceParser
  symbol "-- AP local definitions"
  bindings'' <- many bindingParser
  let bindings' = bindings''
  symbol "-- AP rules"
  rules' <- many ruleParser
  let rules = fromList rules'
  symbol "-- AP scheduling pragmas"
  symbol "[]"
  symbol "-- AP interface"
  methods' <- many methodParser
  let rdyBindings = [("RDY_" ++ name, Binding Nothing 1 guard) | (name, guard, _, _) <- methods']
  let valueBindings = [("BODY_" ++ name, Binding Nothing size expr) |
                       (name, _, expr, Method (Value size) _ _) <- methods']
  let avBindings = [("BODY_" ++ name, Binding Nothing size expr) |
                    (name, _, expr, Method (ActionValue size) _ _) <- methods']
  let bindings = fromList $ bindings' ++ rdyBindings ++ valueBindings ++ avBindings
  let methods = fromList [(name, meth) |
                          (name, _, _, meth) <- methods']
  symbol "-- AP "
  symbol "-- AP instance comments"
  priorityList <- priorityParser
  instArgs <- many instArgsParser
  let insts = fromList [(name, Inst modName undefined undefined args)
                        | ((name, modName, _, _), (_, args)) <- tail . tail $ zip insts' instArgs]
  let (_, _, conflict, fps) = head insts'
  symbol "-- AP remaining proof obligations"
  symbol "[]"
  symbol "-----"
  return $ Module modName insts bindings rules methods fps conflict priorityList

modulesParser = do
  ms <- many moduleParser
  return [m | m <- ms, drop ((length $ moduleName m) - 3) (moduleName m) /= "_fp"]
