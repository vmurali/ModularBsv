module ExprParser where

import Text.Parsec
import Lexer
import DataTypes
import Debug.Trace

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
  ids <- many1 $ terminal
  return $ Expr (Word op) ids

-- MUST TODO THIS
--concatParser = do
--  ids <- sepBy1 terminal (reservedOp "++")
--  return $ Expr (Word "concat") ids

methCallParser = do
  (name, args) <- finalMCallParser
  return $ Expr (MethCall name) args

-- Order is important
exprParser =
  choice [try (do{val <- x; semi; return val}) |
          x <- [methCallParser, concatParser, 
                binaryParser, unaryParser, wordParser]]
--                noneParser, unaryParser, binaryParser,
--                wordParser, concatParser, methCallParser]]

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

data NestedIdentifier a = Node [NestedIdentifier a]
  | Leaf a
  deriving(Show,Eq)

nestedIdentifiers parserOfIdentifier open close = do
  nextNesting <- (between open close) . many $
      (try (nestedIdentifiers parserOfIdentifier open close)) <|> fmap Leaf parserOfIdentifier
  return $ Node nextNesting

balanced open close =  do
  nestedIdentifiers (noneOf [open, close]) (symbol [open]) (symbol [close])
  return ()

concatParser = do
  treeOfIdentifiers <- noOuterParensConcat terminal 
  return (Expr (Word "concat") $ process treeOfIdentifiers)
  where
    process (Leaf a) = [a]
    process (Node l) = concatMap process l

noOuterParensConcat parserOfIdentifier = fmap Node (sepBy (try (outerParensConcat parserOfIdentifier) <|> fmap Leaf parserOfIdentifier) $ symbol "++" )

outerParensConcat parserOfIdentifier = parens $ noOuterParensConcat parserOfIdentifier
