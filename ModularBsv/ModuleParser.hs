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
  symbol "[]"
  reserved "clock"
  braces $ do{reserved "osc"; reservedOp "="; identifier}
  reserved "reset"
  braces identifier
  reserved "clock"
  reserved "info"
  parseClockLine
  reserved "reset"
  reserved "info"
  parseResetLine
  reserved "arg"
  reserved "info"
  brackets $ do{reserved "clockarg"; identifier; semi; comma; reserved "reset"; identifier; semi}
  symbol "-- APackage clock domains"
  brackets $ parens (do{integer; comma; brackets parseOscLine})
  brackets $ parens (do{integer; comma; parseWireLine})
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
  let insts = fromList [(name, Inst modName width init args)
                        | ((name, modName, _, width, init, _), (_, args)) <- tail . tail $ zip insts' instArgs]
  let (_, _, conflict, _, _, fps) = head insts'
  symbol "-- AP remaining proof obligations"
  symbol "[]"
  symbol "-----"
  return $ Module modName insts bindings rules methods fps conflict priorityList

modulesParser = do
  ms <- many moduleParser
  return $ ehr:[m | m <- ms, drop ((length $ moduleName m) - 3) (moduleName m) /= "_fp"]

ehrList = [0..5]

ehr = Module
  { moduleName = "mkEhr"
  , instances = empty
  , bindings = empty
  , rules = empty
  , methods = fromList ([("r" ++ show x, ehrRead) | x <- ehrList] ++
                        [("w" ++ show x, ehrWrite) | x <- ehrList])
  , fps = empty
  , fpConflict = fromList
      ([(("r", "r"), if x < y then SB else if x == y then CF else SA)| x <- ehrList, y <- ehrList] ++
       [(("r", "w"), if x <= y then SB else SA)| x <- ehrList, y <- ehrList] ++
       [(("w", "r"), if x < y then SB else SA)| x <- ehrList, y <- ehrList] ++
       [(("w", "w"), if x < y then SB else if x == y then C else SA)| x <- ehrList, y <- ehrList])
  , priorityList = []
  }

ehrRead = Method
	{ methodType = Value 0
	, methodArgs = []
	, methodBody = []
	}

ehrWrite = Method
	{ methodType = Action
	, methodArgs = [("x", 0)]
	, methodBody = []
	}
