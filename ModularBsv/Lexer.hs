module Lexer where


import Control.Applicative hiding ((<|>), many)
import Text.Parsec hiding (token)
import qualified Text.Parsec.Token as P
import Text.Parsec.Language

lexer = P.makeTokenParser defn

defn = emptyDef {
  P.identStart = letter <|> oneOf "_$",
  P.identLetter = alphaNum <|> oneOf "_$-"
}

--operator   = choice $ map string ["++","||","&&","+","-"]  --Operators supported 
whiteSpace = P.whiteSpace lexer  --comments are judged as whitespaces
brackets = P.brackets lexer
braces = P.braces lexer
semi = P.semi lexer
dot = P.dot lexer
comma = P.comma lexer
colon = P.colon lexer
identifier = P.identifier lexer
lexeme = P.lexeme lexer
reserved = P.reserved lexer    
reservedOp = P.reservedOp lexer
symbol = P.symbol lexer
integer = P.integer lexer
parens = P.parens lexer
stringLiteral = P.stringLiteral lexer
operator = P.operator lexer

constant = do
  size <- integer
  char '\''
  base <- oneOf "bdohBDOH"
  val <- integer
  return $ (show size) ++ "\'" ++ show base ++ show val

quotedString = do
  xs <- between (symbol "\"") (symbol "\"") (many $ noneOf "\"")
  return $ "\"" ++ xs ++ "\""

typedIdentifier =
  parens (symbol "_" *> option "0" (brackets identifier) <* symbol "::" <* symbol "Bit" <* integer)

terminal = try typedIdentifier <|> try quotedString <|>
           try identifier <|> constant

finalMCallParser = do
  m <- identifier
  dot
  h <- identifier
  args <- many terminal
  return ((m,h), args)


