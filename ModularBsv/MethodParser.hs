module MethodParser where

import Text.Parsec
import Lexer
import DataTypes
import ExprParser
import RuleParser
import InstanceParser

headerParser = do
  symbol "-- AP"
  symbol "apkg_interface def"
  identifier

methodArgParser = do
  name <- identifier
  reservedOp "::"
  reserved "Bit"
  size <- integer
  semi
  return (name, size)

methodArgsParser = many methodArgParser

commonBeginMethodParser symb = do
  headerParser
  symbol symb
  name <- identifier
  args <- methodArgsParser
  return (name, args)

commonEndMethodParser = do
  reserved "pred"
  colon
  identifier
  instMethParser

simpleValueParser = do
  (name, args') <- commonBeginMethodParser "--AIDef"
  let (_, size) = last args'
  let args = init args'
  identifier
  reservedOp "="
  expr <- exprParser
  commonEndMethodParser
  return (name, size, args, expr) 

actionParser = do
  (name, args) <- commonBeginMethodParser "--AIAction"
  reservedOp "["
  (_, Rule _ body) <- ruleParser
  commonEndMethodParser
  (_, _, _, guard) <- simpleValueParser
  return (name, guard, undefined, Method Action args body)

valueParser = do
  (name, size, args, expr) <- simpleValueParser
  (_, _, _, guard) <- simpleValueParser
  return (name, guard, expr, Method (Value size) args [])

actionValueParser = do
  (name, args') <- commonBeginMethodParser "--AIActionValue"
  let (_, size) = last args'
  let args = init args'
  identifier
  reservedOp "="
  expr <- exprParser
  reservedOp "["
  (_, Rule _ body) <- ruleParser
  commonEndMethodParser
  (_, _, _, guard) <- simpleValueParser
  return (name, guard, expr, Method (ActionValue size) args body)

methodParser =
  try actionParser <|>
  try actionValueParser <|>
  valueParser
