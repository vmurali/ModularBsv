module TestParsers where

import Control.Monad
import Control.Exception (assert)
import Control.Applicative hiding ((<|>), many)
import Data.Char
import Data.List
import qualified Data.Map as Map
import qualified Data.String.Utils as S

import Debug.Trace
import Text.Parsec hiding (token)
import Text.Parsec.String

import qualified Text.ParserCombinators.Parsec.Token as P

--
-- DataTypes : It's the output of the parser


--AST of ATS

data Expression = And String String
	| Or String String
	| Not String
	| Mux String String String
	| Extract String Integer Integer 
	| MCall MExpression --The same
	| Equal String String
	| Concat [String] --Concat wires
	| Plus String String
	| Minus String String
	deriving(Show,Eq)

data Module = Module { name :: String
	, instances :: [ Instance ]
	, bindings :: [ Binding ]
	, rules :: [ Rule ]
	, methods :: [ Method ]
	, fps :: [ Fp ]
	, conflictMatrix :: Map.Map (String, String) Conflict 
	, priorityList :: [ [ String ] ]
} deriving(Show,Eq)--Done

data Conflict =  C | CF | SB | SA deriving(Show,Eq)

data Instance = Instance {instName :: String
	, moduleName :: String
	, args :: [ String ]
} deriving(Show,Eq)--Done

data Binding = Binding {bindName :: String
	, size :: Integer 
	, expression :: Expression
} deriving(Show,Eq)--Done

data Rule = Rule {ruleName :: String
	, ruleGuard :: String 
	, ruleBody :: [ MExpression ]
} deriving(Show,Eq)--Done


data Method = Method {methodName :: String
	, methodGuard :: String 
	, methodType :: TypeOfMethod  
	, methodArgs :: [(String, Integer)]
	, methodBody :: [ MExpression ]
} deriving(Show,Eq) --Done

data Fp = Fp {fpName :: String
	, fpType :: TypeOfMethod
	, fpArgs :: [ (String,Integer) ]
} deriving(Show,Eq)

-- Unit operations in the body of a method.
data MExpression = MExpression {cond :: Maybe String 
	, moduleCalledName :: String
	, calledMethod :: String 
	, argsMethod :: [ String ]
} deriving(Show,Eq)--Done 


--The integers are the size of the result
data TypeOfMethod = Value Integer  
	| Value0 Integer
	| Action
	| ActionValue Integer
	deriving(Show,Eq)
--
--Lexer and Parsers of the ATS language 
--

lexer = P.makeTokenParser defn

defn = P.LanguageDef {
  P.commentStart = "/*",
  P.commentEnd = "*/",
  P.commentLine = "--",
  P.nestedComments = False,
  P.opStart =  undefined,
  P.opLetter = undefined,
  P.reservedOpNames = undefined,
  P.identStart      = letter,
  P.identLetter     = alphaNum <|> char '_',
  P.reservedNames   = [ 
                      ],
  P.caseSensitive   = True
}

operator   = choice $ map string ["++","||","&&","+","-"]  --Operators supported 
whiteSpace = P.whiteSpace lexer  --comments are judged as whitespaces
brackets   = P.brackets lexer
braces     = P.braces lexer
semi       = P.semi lexer
comma      = P.comma lexer
colon      = P.colon lexer
identifier = P.identifier lexer
lexeme     = P.lexeme lexer
reserved   = P.reserved lexer    
reservedOp = P.reservedOp lexer
parens     = P.parens lexer
wSpace     = many $ char ' ' <|> char '\t'
emptyArea  = many $ char ' ' <|> char '\t' <|> char '\n'

--
-- Parser of arguments / guards. 
-- It's a more general Parser than the identifier
-- e.g "8d'5464" is parsed  by guardParser.
-- 
-- TODO : Maybe we can always replace [identifier] by [guardParser]
--

guardParser = emptyArea *> (many1 $ noneOf ['\n',' ','\t',';'])    

---
--- Parser of instances
---



instancesParser :: Parser [Instance]
instancesParser = do
	listInstances <- many $ instanceParser
	let (onlyFpInstances,_) = partition (\x -> S.endswith "_fp" (moduleName x)) listInstances
	listFp <- apInstanceDocParser
	return $ process listInstances onlyFpInstances		
	  where 
		process (t:q) (r:s) =(t{args = args r} :(process q s))
		process [] [] = []

 
instanceParser :: Parser Instance
instanceParser = do
	toTrash <-many $ anyChar <* notFollowedBy (identifier <* string " :: ABSTRACT")
	nameInst <- identifier
	emptyArea *> string ":: ABSTRACT:" <* emptyArea
	notImportant <- guardParser        --Well, not important but we store, never know
	emptyArea *> string "=" <* emptyArea 
	nameModule <- identifier <* emptyArea
	return $ Instance {instName = nameInst 
			, moduleName = nameModule 
			, args = undefined }


apInstanceDocParser :: Parser [Instance]
apInstanceDocParser = lookAhead $
	 do{many (try $ do{anyChar;
			; notFollowedBy (string "-- AP instance comments\n")
			})
	; string "-- AP instance comments\n"  
	; formalParametersParser}  




-- 
-- Parser of bindings 
--


bindingParser :: Parser Binding 
bindingParser = do
--We parse the first line
	name <- identifier 
	wSpace
	string ":: Bit "
	size <- many digit 		
	wSpace
	char ';'
	emptyArea
--We parse the second line with the same name
	string name
	string " ="
	expression <- expressionParser	
	return $ Binding{bindName = name
			, size = numberValue 10 size 
			, expression = expression}

expressionParser :: Parser Expression
expressionParser = ( choice [try listParser, try binaryParser, try unaryParser]) <* string ";" 

listParser :: Parser Expression
listParser = do
	--Dirty hack. TODO sepBy2 
	first <- emptyArea *> guardParser  <* emptyArea 
	string "++"    
	list  <- (emptyArea *> guardParser <* emptyArea)  `sepBy1` string "++" 
	return $ Concat $ first:list

binaryParser :: Parser Expression 
binaryParser = do
	name1 <- (emptyArea *> guardParser <* emptyArea)	
	op <-  operator
	name2 <- (emptyArea *> guardParser <* emptyArea)					
	return $  k op name1 name2
	where 	k op name1 name2 = case (lookup op l) of
					Just a -> a name1 name2
					Nothing -> undefined --Fraction of BSV
		l = [("&&", \x y -> And x y ),
			("||", \x y -> Or x y ),
			("+", \x y -> Plus x y ),
			("-", \x y -> Minus x y )]

unaryParser :: Parser Expression   
unaryParser =
	choice [ k "_if_" $ do{first <- emptyArea *> guardParser
				; second <- emptyArea *> guardParser
				; third <- emptyArea *> guardParser
				; emptyArea
				; return $ Mux first second third }
              , k "extract" $ undefined  
              , k "!" $ undefined ]
  where
    k x p = (emptyArea *> string x) *> p



--
-- Parsers for rules 
-- Typical format :
-- rule RL_start "start":
--  when proc_RDY_hostToCpu_AND_NOT_state___d4
--   ==> { proc.hostToCpu 32'h1000; state.write 1'd1; }

ruleParser :: Parser Rule 
ruleParser = do
	emptyArea *> string "rule"
	processedName <- wSpace *> identifier <* wSpace
	realName <- string "\"" *> identifier  <* string "\":" 			
	guard <- emptyArea *> string "when" *> guardParser <* emptyArea 
	string "==>"
	emptyArea
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> methodCallParser) 	 		
	return $ Rule{ruleName = processedName 
			, ruleGuard = guard
			, ruleBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{cond = t, moduleCalledName = x, calledMethod = y, argsMethod = z})	


		
-- Parser for bodies of methods/rules

ifMethodCallParser = do
	emptyArea *> string "if" <* emptyArea 
	nameCond  <- guardParser 
	emptyArea *> string "then"
	(cond,moduleName,methodName,args) <- methodCallParser
	return $ (Just nameCond, moduleName, methodName, args)    	

methodCallParser = do 
	moduleName <- emptyArea *> identifier <* char '.'	
	methodName <- identifier <* emptyArea 
        args <- many $ guardParser <* emptyArea 
	char ';'
	emptyArea
	return $ (Nothing, moduleName, methodName, args)



--
-- Parsers for methods
--
--
-- /!\			 /!\
-- /!\TODO: Need clean up/!\
-- /!\			 /!\

data ResultOrArg = Result | Arg deriving(Show,Eq)

methodParser :: Parser Method
methodParser = do
	listArgs <- many $  (try resultParser) <|> argMethodParser
	let (lResult, lArgs) = partition (\(x,y,z) -> x == Result) listArgs  --TODO : check the partition function  
	method <- brackets $ methodBodyParser 
	return method{methodArgs = process1 lArgs, methodType = process2 lArgs lResult}
	  where	process1 = map (\(x,y,z) ->(y,z)) 
		process2 args res = case res of
			[] -> Action  
			[(_,_,b)] -> case args of
				[] -> Value0 b 
				_  -> Value b
			_ -> undefined --TODO Correct?	  



argMethodParser :: Parser (ResultOrArg,String,Integer)
argMethodParser = do
	name <- identifier 
	wSpace
	string ":: Bit "
	size <- many digit 		
	wSpace
	char ';'
	emptyArea
	return (Arg, name, numberValue 10 size)
		
resultParser :: Parser (ResultOrArg,String,Integer)
resultParser = do
	wSpace
	name <- emptyArea *> identifier  <* emptyArea <* string ":: Bit "
	size <- many digit <* emptyArea
	char ';'
	--Second line : assignment
	emptyArea *> string name <*string " ="
	expression <- expressionParser	
	return $ (Result, name, numberValue 10 size)
		

--TODO factorize : we can use ruleBodyParser here.
methodBodyParser :: Parser Method 
methodBodyParser = do
	string "rule"
	processedName <- wSpace *> identifier <* wSpace  
	realName <- string "\"" *> identifier  <* string "\":" 			
	notImportant <- emptyArea *> string "when" *> guardParser <* emptyArea 
	string "==>"
	wSpace
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> methodCallParser) 	 		
	trash <- many $ noneOf [']']    --We have to eat all the useless stuff, until the ] appears. 
	return $ Method{methodName = processedName 
			, methodGuard = "RDY_" ++ processedName  --TODO check if we need bindings
			, methodType = undefined
			, methodArgs = undefined
			, methodBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{cond = t, moduleCalledName = x, calledMethod = y, argsMethod = z})	


--
--Formal parameters parser : use docs of BSV.
-- /!\ Need merge with home version.

formalParametersParser :: Parser [Instance]
formalParametersParser = many $ formalParameterParser

formalParameterParser :: Parser Instance
formalParameterParser = do
	name <- emptyArea *>identifier <* string ":"
	emptyArea
	par <- parens $ (many $ emptyArea *> identifier <* emptyArea)  
	return Instance{instName = name
		, moduleName = "test" --Not implemented yet 
		, args = par}

--
-- Tools
--

numberValue :: Integer -> String ->  Integer
numberValue n [a] = toInteger . digitToInt $ a 
numberValue n (t:q) =n*(numberValue n q) + (toInteger . digitToInt $  t)




