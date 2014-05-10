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
import Debug.Trace
import Control.Applicative hiding ((<|>), many, empty)

moduleExtraParser = do
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
  brackets $ do{reserved "clockarg"; identifier; semi; comma; reserved "resetarg"; identifier; semi}
  symbol "-- APackage clock domains"
  brackets $ parens (do{integer; comma; brackets parseOscLine})
  brackets $ parens (do{integer; comma; parseWireLine})
  symbol "-- AP state elements"

moduleParser = do
  symbol "=== ATS:"
  symbol "APackage"
  modName <- identifier
  moduleExtraParser

  insts' <- many $ try (instanceParser)

  symbol "-- AP local definitions"
  bindings'' <- many $ try bindingParser
  let bindings' = bindings''
  symbol "-- AP rules"
  rules' <- many $ try ruleParser
  let rules = fromList rules'
  symbol "-- AP scheduling pragmas"
  symbol "[]"
  symbol "-- AP interface"
  methods' <- many $ try methodParser
  let rdyBindings = [("RDY_" ++ name, Binding Nothing 1 guard) | (name, guard, _, _) <- methods']
  let valueBindings = [("BODY_" ++ name, Binding Nothing size expr) |
                       (name, _, expr, Method (Value size) _ _) <- methods']
  let avBindings = [("BODY_" ++ name, Binding Nothing size expr) |
                    (name, _, expr, Method (ActionValue size) _ _) <- methods']
  let bindings = fromList $ bindings' ++ rdyBindings ++ valueBindings ++ avBindings
  let methods = fromList [(name, meth) |
                          (name, _, _, meth) <- methods']
  symbol "-- AP instance comments"
  priorityList <- priorityParser
  instArgs' <- many instArgsComments
  let instArgs = fromList instArgs'
  let insts'' = if (insts' /= [] && let (nm, _, _, _, _, _, _) = head insts' in nm == "fp1")
                  then tail $ tail insts'
                  else insts'
  let insts = fromList [(name, Inst modName width init sz (findWithDefault [] name instArgs))
                        | (name, modName, _, width, init, sz, _) <- insts'']
  let (_, _, conflict, _, _, _, fps) = head insts'
  symbol "-- AP remaining proof obligations"
  symbol "[]"
  symbol "-----"
  do{x <- lookAhead (count 20 anyChar); y <- getPosition;
     trace (show y ++ "[" ++ show instArgs ++ "]") (return ())}
  return $ Module modName insts bindings rules methods fps conflict priorityList

instArgsComments = do
  id <- identifier
  colon
  args <- many $ do {x <- identifier; dot; y <- identifier; return (x, y)}
  return (id, args)

modulesParser = do
  ms <- many $ try moduleParser
  return $ ehr : regFile : ms

regFile = Module
  { moduleName = "mkRegFile"
  , instances = empty
  , bindings = empty
  , rules = empty
  , methods = fromList [("sub", Method (Value 0) [("x", 0)] []), ("upd", Method Action [("x", 0), ("y", 0)] [])]
  , fps = empty
  , fpConflict = fromList [(("sub", "sub"), C), (("upd", "upd"), C), (("sub", "upd"), SB), (("upd", "sub"), SA)]
  , priorityList = []
  }

ehrList = [0..3]

ehr = Module
  { moduleName = "mkEHR"
  , instances = empty
  , bindings = empty
  , rules = empty
  , methods = fromList ([("r" ++ show x, Method (Value 0) [] []) | x <- ehrList] ++
                        [("w" ++ show x, Method Action [("x", 0)] []) | x <- ehrList])
  , fps = empty
  , fpConflict = fromList
      ([(("r" ++ show x, "r" ++ show y), if x < y then SB else if x == y then CF else SA)| x <- ehrList, y <- ehrList] ++
       [(("r" ++ show x, "w" ++ show y), if x <= y then SB else SA)| x <- ehrList, y <- ehrList] ++
       [(("w" ++ show x, "r" ++ show y), if x < y then SB else SA)| x <- ehrList, y <- ehrList] ++
       [(("w" ++ show x, "w" ++ show y), if x < y then SB else if x == y then C else SA)| x <- ehrList, y <- ehrList])
  , priorityList = []
  }
