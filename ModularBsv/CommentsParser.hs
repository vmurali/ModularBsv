module CommentsParser where

import Text.Parsec
import Lexer
import DataTypes

priorityParser = do
  reserved "fp1"
  colon
  many $ try (brackets $ many (try $ do {id1 <- identifier; dot;
                                         id2 <- identifier; return (id1, id2)}))

instArgsParser = do
  id <- identifier
  colon
  args <- many (try $ do {id1 <- identifier; id2 <- identifier; return (id1, id2)})
  return (id, args)
