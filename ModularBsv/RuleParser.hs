module RuleParser where

import Text.Parsec
import Lexer
import DataTypes

mcallIfParser = do
  reserved "if"
  cond <- identifier
  reserved "then"
  (name, args) <- finalMCallParser
  return $ Calleds cond name args

mcallNoIfParser = do
  (name, args) <- finalMCallParser
  return $ Calleds "1'b1" name args

mcallParser = try mcallIfParser <|> try mcallNoIfParser

ruleParser = do
  reserved "rule"
  name <- identifier
  quotedString
  colon
  reserved "when"
  guard <- terminal
  reservedOp "==>"
  mcalls <- braces (many $ do {x <- mcallParser; semi; return x})
  symbol "[]"
  return (name, Rule guard mcalls)
