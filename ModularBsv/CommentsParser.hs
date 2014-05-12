module CommentsParser where

import Text.Parsec
import Lexer
import DataTypes
import Debug.Trace

instArgsParser = do
  id <- identifier
  colon
  args <- many $ try (brackets $ many (try $ do {id1 <- identifier; dot;
                                                 id2 <- identifier; return (id1, id2)}))
  return (id, args)
