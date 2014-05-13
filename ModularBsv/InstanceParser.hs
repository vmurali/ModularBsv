module InstanceParser where

import Data.Maybe
import Text.Parsec
import Lexer
import DataTypes
import Data.Map
import Debug.Trace
import ExprParser
import Control.Applicative hiding ((<|>), optional, many)
import qualified Text.ParserCombinators.Parsec.Prim as P

-- TODO : Take care of EHRs, width, initial value - requires changing the parser slightly


instArgParser = parens $ do
  name <- identifier
  comma
  brackets $ optional identifier
  return name

instMethParser = do
  reserved "method"
  optional instArgParser
  name <- identifier
  args <- option [] $ ((try $ parens (sepBy instArgParser comma)) <|> (symbol "[0]" *> return []))
  optional (do{reserved "enable"; parens instArgParser})
  reserved "clocked_by"
  parens identifier
  reserved "reset_by"
  parens identifier
  return (name, args)

justParser = do
  reserved "Just"
  i <- parens $ do
         identifier --- Must be reserved "Bit". Stupid encoding error omits the "t" sometimes
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
  reserved "types"
  reservedOp "="
  x <- brackets $ do
    sepBy (singleInstMethTypeParser) comma
  return x

singleOrListParser =
  try (do{x <- identifier; return [x]}) <|>
  brackets (sepBy identifier comma)

conflictParser =
  try (do {reserved "CF"; return CF}) <|>
  try (do {reserved "SB"; return SB}) <|>
  try (do {reserved "SBR"; return SB}) <|>
  try (do {reserved "C"; return C})

schedStmtParser = do
  x <- singleOrListParser
  conf <- conflictParser
  y <- singleOrListParser
  return (x, y, conf)

ignoreTillCloseOpenReset = do
  manyTill anyChar (try $ lookAhead (do{symbol ")"; symbol "["; 
    try (do {reserved "reset"; symbol "{"; reserved "wire"}) <|>
    (do {reserved "clock"; symbol "{"; reserved "osc"})}))

parseSched = do
  reserved "SchedInfo"
  scheds <- brackets (sepBy schedStmtParser comma)
  count 4 (balanced '[' ']')
  return scheds

inverseConf conf =
  case conf of
    C -> C
    SB -> SA
    SA -> SB
    CF -> CF

getConflict scheds = fromList $
  [((x, y), conf) | (xs, ys, conf) <- scheds,
                     x <- xs, y <- ys, take 4 x /= "RDY_", take 4 y /= "RDY_"] ++
  [((y, x), inverseConf conf) | (xs, ys, conf) <- scheds,
                                 x <- xs, y <- ys, take 4 x /= "RDY_", take 4 y /= "RDY_"]

parseClockLine = do
  reserved "clock"
  identifier
  parens $ do
    identifier
    comma
    (try $ do{symbol "{-"; identifier; symbol "-}"}) <|> identifier
  semi

parseResetLine = do
  reserved "reset"; identifier;
  parens identifier; reserved "clocked_by"; parens identifier; semi;

parseOscLine = braces (do{reserved "osc"; colon; identifier; reserved "gate"; colon; constant})

parseWireLine = braces (do{reserved "wire"; colon; identifier});

vmodInfoParser = do
  (meths, sched) <- parens $ do
    reserved "VModInfo"
    identifier
    parseClockLine
    parseResetLine
    brackets (sepBy (do{identifier; identifier; semi}) comma)
    meths <- brackets (sepBy (instMethParser <* semi <* comma <* instMethParser <*
        semi) comma)
    sched <- parseSched
    return (meths, sched)
  (width, init, size) <- brackets $ do
    try (reserved "clock" >> parseOscLine >> comma >> reserved "reset" >> parseWireLine) <|>
      (reserved "reset" >> parseWireLine >> comma >> reserved "clock" >> parseOscLine)
    width <- option (Expr None []) (try $ comma >> ((try concatParser) <|> noneParser))
    init <- option (Expr None []) (try $ comma >> ((try concatParser) <|> noneParser))
    size <- option (Expr None []) (try $ comma >> ((try concatParser) <|> noneParser))
    return (width, init, size)
  return (meths, sched, width, init, size)

instanceParser = do
  name <- identifier
  symbol "::"
  symbol "ABSTRACT"
  symbol ":"
  sepBy identifier dot
  symbol "="
  modName <- identifier
  (meths, sched, width, init, sz) <- vmodInfoParser
  symbol "[]"
  methTypes <- instMethTypeParser
  many (balanced '(' ')')
  return $ (name, modName, getConflict sched, width, init, sz,
    [(if isEn
        then case retSize of
               Just size -> Fp name (ActionValue size) (zip args argSize)
               Nothing -> Fp name Action (zip args argSize)
        else case retSize of
               Just size -> Fp name (Value size) (zip args argSize)
               Nothing -> Fp name (Value 0) (zip args argSize))
      | ((name, args), (argSize, retSize, isEn)) <- zip meths methTypes])
