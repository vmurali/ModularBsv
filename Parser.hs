module Parser where

parseInst :: Parser (InstName, Instance)
parseInst = do
  instName <- identifier
  stringLiteral ":: ABSTRACT:"
  sepBy identifier dot
  symbol "="
  instModule <- identifier
  symbol "("
  do {stringLiteral "VModInfo"; identifier;
      stringLiteral "clock"; identifier; parens $ sepBy (noneOf ",") comma;
      stringLiteral "reset"; many $ do{identifier; parens identifier};
      brackets $ sepBy "," do{identifier; identifier; semi}}
  symbol ")"

moduleParser :: Parser Module
moduleParser = do
  stringLiteral "=== ATS:"
  stringLiteral "APackage"
  modName <- identifier
  manyTill anyChar (try $ stringLiteral "-- AP state elements")
  insts <- many parseInst
  stringLiteral "-- AP local definitions"
  bindings <- many parseBinding
  stringLiteral "-- AP rules"
  rules <- many parseRule
  manyTill anyChar (try $ stringLiteral "-- AP interface")
  methods <- many parseMethod
  stringLiteral "-- AP "
  stringLiteral "-- AP instance comments"
  comments <- many parseComments
  stringLiteral "-- AP remaining proof obligations"
  stringLiteral "[]"
  stringLiteral "-----"

