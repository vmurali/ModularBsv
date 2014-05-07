module CommentsParser where

import Text.Parsec
import Lexer
import DataTypes

priorityParser = do
  reserved "fp1"
  colon
  many (brackets $ many $ do {id1 <- identifier; id2 <- identifier; return (id1, id2)})

instArgsParser = do
  id <- identifier
  colon
  args <- many $ do {id1 <- identifier; id2 <- identifier; return (id1, id2)}
  return (id, args)
