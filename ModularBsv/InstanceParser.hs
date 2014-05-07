module InstanceParser where

import Data.Maybe
import Text.Parsec
import Lexer
import DataTypes
import Data.Map

-- TODO : Take care of EHRs, width, initial value - requires changing the parser slightly

instArgParser = parens $ do
  name <- identifier
  comma
  symbol "[]"
  return name

instMethParser = do
  reserved "method"
  optional instArgParser
  name <- identifier
  args <- parens (sepBy instArgParser comma)
  optional (do{reserved "enable"; instArgParser})
  reserved "clocked_by"
  parens identifier
  reserved "reset_by"
  parens identifier
  return (name, args)

justParser = do
  reserved "Just"
  i <- parens $ do
         reserved "Bit"
         integer
  return $ Just i

maybeParser =
  try justParser <|> do{reserved "Nothing"; return Nothing}

singleInstMethTypeParser = parens $ do
  args <- brackets (sepBy (do{reserved "Bit"; integer}) comma)
  comma
  enable <- maybeParser
  comma
  retVal <- maybeParser
  return (args, retVal, isJust enable)

instMethTypeParser = do
  reserved "meth"
  reserved "type"
  reservedOp "="
  brackets $ do
    sepBy (singleInstMethTypeParser) comma

singleOrListParser =
  try (do{x <- identifier; return [x]}) <|>
  brackets (sepBy identifier comma)

conflictParser =
  try (do {reserved "CF"; return CF}) <|>
  try (do {reserved "SB"; return SB}) <|>
  try (do {reserved "C"; return C})

schedStmtParser = do
  x <- singleOrListParser
  conf <- conflictParser
  y <- singleOrListParser
  return (x, y, conf)

parseSched = do
  scheds <- brackets (sepBy schedStmtParser comma)
  symbol "[]"
  symbol "[]"
  symbol "[]"
  symbol "[]"
  return scheds

inverseConf conf =
  case conf of
    C -> C
    SB -> SA
    SA -> SB
    CF -> CF

getConflict scheds = fromList $
  [((x, y), conf) | (xs, ys, conf) <- scheds,
                     x <- xs, y <- ys] ++
  [((y, x), inverseConf conf) | (xs, ys, conf) <- scheds,
                                 x <- xs, y <- ys]

instanceParser = do
  name <- identifier
  symbol ":: ABSTRACT:"
  sepBy identifier dot
  reserved "="
  modName <- identifier
  (meths, sched) <-
     parens $ do { reserved "VModInfo"; identifier;
                   meths <- braces (sepBy (do{x <-instMethParser; semi; return x}) comma);
                   sched <- parseSched;
                   return (meths, sched)}
  symbol "[]"
  methTypes <- instMethTypeParser
  return $ (name, modName, getConflict sched, fromList
    [ (name, if isEn
               then case retSize of
                      Just size -> Fp (ActionValue size) (zip args argSize)
                      Nothing -> Fp Action (zip args argSize)
               else case retSize of
                      Just size -> Fp (Value size) (zip args argSize)
                      Nothing -> Fp (Value 0) (zip args argSize))
      | ((name, args), (argSize, retSize, isEn)) <- zip meths methTypes])
