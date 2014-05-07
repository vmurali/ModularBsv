module ExprParser where

import Text.Parsec
import Lexer
import DataTypes

noneParser = do
  id <- terminal
  return $ Expr None [id]

unaryParser = do
  op <- operator
  id <- terminal
  return $ Expr (Unary op) [id]

binaryParser = do
  id1 <- terminal
  op <- operator
  id2 <- terminal
  return $ Expr (Binary op) [id1, id2]

wordParser = do
  op <- terminal
  ids <- many1 terminal
  return $ Expr (Word op) ids

concatParser = do
  ids <- sepBy1 terminal (reservedOp "++")
  return $ Expr (Word "concat") ids

methCallParser = do
  (name, args) <- finalMCallParser
  return $ Expr (MethCall name) args

exprParser =
  choice [try (do{val <- x; semi; return val}) |
          x <- [noneParser, unaryParser, binaryParser,
                wordParser, concatParser, methCallParser]]

bindingParser = do
  name <- identifier
  reservedOp "::"
  array <- optionMaybe (reserved "Array" >> integer)
  reserved "Bit"
  size <- integer
  semi
  identifier
  reservedOp "="
  expr <- exprParser
  return $ (name, Binding array size expr)
