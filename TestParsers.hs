module TestParsers where

import Control.Monad
import Control.Exception (assert)
import Control.Applicative hiding ((<|>), many)
import Data.Char
import qualified Data.List as List
import qualified Data.Maybe as Maybe
import qualified Data.Map as Map
import qualified Data.String.Utils as S
import qualified Data.Either as E

import Debug.Trace
import Text.Parsec hiding (token)
import Text.Parsec.String
import Text.Parsec.Prim

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
	, instModule :: String
	, instArgs :: [ String ]
} deriving(Show,Eq)--Done

data Binding = Binding {bindName :: String
	, bindSize :: Integer 
	, bindExpr :: Expression
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
data MExpression = MExpression {calledCond :: Maybe String 
	, calledModule :: String
	, calledMethod :: String 
	, calledArgs :: [ String ]
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
  P.commentLine = "**********",
  P.nestedComments = False,
  P.opStart =  trace "l103" $ undefined,
  P.opLetter = trace "l104" $ undefined,
  P.reservedOpNames = trace "l105" $ undefined,
  P.identStart      = alphaNum <|> oneOf "_$\'",
  P.identLetter     = alphaNum <|> oneOf "_$\'",
  P.reservedNames   = [ 
                      ],
  P.caseSensitive   = True
}

--operator   = choice $ map string ["++","||","&&","+","-"]  --Operators supported 
whiteSpace = P.whiteSpace lexer  --comments are judged as whitespaces
brackets   = P.brackets lexer
braces     = P.braces lexer
semi       = P.semi lexer
dot 	   = P.dot lexer
comma      = P.comma lexer
colon      = P.colon lexer
quotedString = between (symbol "\"") (symbol "\"") (many $ noneOf "\"")
identifier = quotedString <|> P.identifier lexer
lexeme     = P.lexeme lexer
reserved   = P.reserved lexer    
reservedOp = P.reservedOp lexer
symbol	   = P.symbol lexer
integer    = P.integer lexer
parens     = P.parens lexer
emptyArea  = many $ char ' ' <|> char '\t' <|> char '\n'

--
-- Parser of arguments / guards. 
-- It's a more general Parser than the identifier
-- e.g "8d'5464" is parsed  by guardParser.
-- 
-- TODO : Maybe we can always replace [identifier] by [guardParser]
--

guardParser = emptyArea *> (many1 $ noneOf ['\n',' ','\t',';',':','(',')',',','=']) <* emptyArea   



---
--- Main Parser : Parser for modules.
---


modulesParser :: Parser [Module]
modulesParser = do
	many . try $ do{manyTill anyChar (try $ reserved "=== ATS:");moduleParser}
	


moduleParser :: Parser Module
moduleParser = do
	manyTill anyChar (try $ reserved "APackage") 
	nameModule <- identifier
	listInstancesAndFormalParameters <-  instancesParser
	manyTill anyChar . try $ reserved "-- AP local definitions"	
	listBindings <- lookAhead . many . try $ do{manyTill anyChar (lookAhead.try $ bindingParser);bindingParser}
	manyTill anyChar . try $ reserved "-- AP rules"	
	listRules<-many . try $ ruleParser
	manyTill anyChar . try $ reserved "-- AP scheduling pragmas"	
	listMethods <- many . try $ do{manyTill anyChar (try . lookAhead $ methodParser); methodParser}
	let (inst,l) = E.partitionEithers listInstancesAndFormalParameters 
	return $ Module{name=nameModule  --Test name
			, instances = inst
			, bindings = listBindings
			, rules = listRules
			, methods = listMethods
			, fps = if null l then []  else (\(x,y,z)->x).head $ l
			, conflictMatrix = if null l then Map.empty else (\(x,y,z)->z).head $ l
			, priorityList = if null l then [] else (\(x,y,z)->y).head $ l} 


---
--- Parser for instances
---


instancesParser :: Parser ([Either Instance ([Fp], [[String]], Map.Map (String,String) Conflict)])
instancesParser = do
	--Either FP, either instance
	listInstances <- lookAhead . many $ (try bodyInstanceParser) <|> (try instanceParser)
	listFp <- apInstanceDocParser
	let (listWithoutFp,singleFp) = List.partition (\x -> instName x /= "fp") listFp
	return $ process listInstances listWithoutFp singleFp
	  where process [] [] fp = []
		process (t:q) [] fp = case t of
					Left a -> (Left a):(process q [] fp)
					Right (a,b) ->(Right(a, map words . instArgs . head $ fp, b)):(process q [] fp)
		process (t:q) (r:s) fp = case t of 
					Left a      -> if instName a == instName r then
							(Left(a{instArgs=instArgs r})):(process q s fp)
							else (Left a):(process q (r:s) fp)
					Right (a,b) ->(Right(a, map words . instArgs . head $ fp, b)):(process q s fp)
					--If hd fails it's that there is no priority list in the sourcecode	


instanceParser :: Parser (Either Instance ([Fp], Map.Map (String,String) Conflict))
instanceParser = do
	toTrash <- manyTill anyChar ((try . lookAhead $ do{test<- identifier
						; symbol "::" <* symbol "ABSTRACT"}))
	nameInst <- identifier
	symbol "::"
	symbol "ABSTRACT:"
	notImportant <- identifier `sepBy` dot
	--Well, not important but we store, never know
	symbol "=" 
	nameModule <- identifier 
        return $ Left Instance {instName = nameInst 
			, instModule = nameModule 
			, instArgs = [] }


apInstanceDocParser :: Parser [Instance]
apInstanceDocParser = lookAhead $
	 do{manyTill anyChar $ (try $ string "-- AP instance comments\n")			
	; formalParametersParser}  



-- 
-- Parser for bindings 
--

--Need checking
bindingParser :: Parser Binding 
bindingParser = do
--We parse the first line
	name <- identifier 
	symbol "::" <* symbol "Bit"
	size <- integer <* semi               -- TODO I think it's correct many digit 		
--We parse the second line with the same name
	symbol name <* symbol "="
	expression <- expressionParser	
	return $ Binding{bindName = name
			, bindSize = size    --Check that 
			, bindExpr = expression}

expressionParser :: Parser Expression
expressionParser = (try listParser <|> try binaryParser <|> try unaryParser) <* symbol ";" 

listParser :: Parser Expression
listParser = do
	--Dirty hack. TODO sepBy2 
	first <- identifier
	symbol "++"   
	list  <- (try identifier) `sepBy1` symbol "++"   --TODO Is "try" required? 
	return . Concat $ first:list  --Check this code -> It was false in my opinion

binaryParser :: Parser Expression 
binaryParser = do
	name1 <- identifier
	op <-  guardParser --I can use operator parser
	name2 <- identifier	
	return $  k op name1 name2
	where 	k op name1 name2 = case (lookup op l) of
					Just a -> a name1 name2
					Nothing -> trace "l261" $ undefined --Fraction of BSV
		l = [("==", \x y -> Equal x y),   --Set of supported operators
			("&&", \x y -> And x y ),
			("||", \x y -> Or x y ),
			("+", \x y -> Plus x y ),
			("-", \x y -> Minus x y )]

unaryParser :: Parser Expression   
unaryParser =
	choice [ k "_if_" $ do{first <- identifier
				; second <- identifier
				; third <- identifier
				; return $ Mux first second third }
              , k "extract" $ (trace "l274" $ undefined)  
              , k "!" $ do{first <- identifier ; return  $ Not first} ]
  where
    k x p = (symbol x) *> p   --TODO Check this fucking emptyArea perhaps needed?


--
-- Parsers for rules 
-- Typical format :
-- rule RL_start "start":
--  when proc_RDY_hostToCpu_AND_NOT_state___d4
--   ==> { proc.hostToCpu 32'h1000; state.write 1'd1; }

ruleParser :: Parser Rule 
ruleParser = do
	manyTill anyChar . try $ symbol "rule"
	processedName <- identifier         --TESTING TODO
	realName <- identifier <* colon               --CHECK THAT	
	guard <- symbol "when" *> identifier <* symbol "==>"
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> (try methodCallParser)) 	 		
	return $ Rule{ruleName = processedName 
			, ruleGuard = guard
			, ruleBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{calledCond = t, calledModule = x, calledMethod = y, calledArgs = z})	


		
-- Parser for bodies of methods/rules

ifMethodCallParser = do
	nameCond  <- symbol "if" *> identifier <* symbol "then"
	(cond,moduleName,methodName,args) <- methodCallParser
	return $ (Just nameCond, moduleName, methodName, args)    	

methodCallParser = do 
	moduleName <- identifier <* symbol "."   --TESTING TODO	
	methodName <- identifier
        args <- (many $ identifier) <* semi 
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
	listArgs <- many $  (try resultParser) <|> try argMethodParser
	let (lResult, lArgs) = List.partition (\(x,y,z) -> x == Result) listArgs  --TODO : check partition  
	method <- brackets $ methodBodyParser 
	return method{methodArgs = process1 lArgs, methodType = process2 lArgs lResult}
	  where	process1 = map (\(x,y,z)->(y,z)) 
		process2 args res = case res of
			[] -> Action  
			[(_,_,b)] -> case args of
				[] -> Value0 b
				_  -> Value b
			_ -> trace "l337" $ undefined --TODO Correct?  ActionValue	  


--TODO prettyfication
argMethodParser :: Parser (ResultOrArg,String,Integer)
argMethodParser = do
	name <- identifier 
	symbol "::" *> symbol "Bit"
	size <- integer <* semi                --Many digit	
	return (Arg, name, size)
		
resultParser :: Parser (ResultOrArg,String,Integer)
resultParser = do
	name <- identifier <* symbol "::" <* symbol "Bit"  --TODO testing
	size <- integer <* semi
	--Second line : assignment
	symbol name <* symbol "="
	expression <- expressionParser	
	return $ (Result, name, size)
		

--TODO factorize : we can use ruleBodyParser here.
methodBodyParser :: Parser Method 
methodBodyParser = do
	symbol "rule"
	processedName <- identifier  --Rely on Whitespace TODO check if I can erase the "  
	realName <- identifier <* colon <* symbol "when" <* identifier  <* symbol "==>"
 	listExpr <- braces $ (many $ (try ifMethodCallParser) <|> methodCallParser) 	 		
	many $ noneOf [']']    --We have to eat all the useless stuff, until the ] appears. 
	return $ Method{methodName = processedName 
			, methodGuard = "RDY_" ++ processedName  --TODO check if we need bindings
			, methodType = trace "methodType" $ undefined
			, methodArgs = trace "methodArgs" $ undefined
			, methodBody = toMExpr listExpr}
	where toMExpr = map (\(t,x,y,z) -> MExpression{calledCond = t, calledModule = x, calledMethod = y, calledArgs = z})	




--
-- Parser for fp with FPs, BVI. 
-- /!\ TODO cleanup
-- TODO : Priority INFOS BETTER 


bodyInstanceParser :: Parser (Either Instance ([Fp], Map.Map (String,String) Conflict))
bodyInstanceParser = do
	toTrash <-  manyTill anyChar . try . lookAhead $ identifier <* symbol "::" <* symbol "ABSTRACT"
	symbol "fp" <* symbol "::" <* symbol "ABSTRACT:" <* (identifier `sepBy` dot) 
	symbol "="
	nameModule <-  identifier 
	-- Eat until my position is good	
	manyTill anyChar . try . lookAhead $ (symbol "[method")
	symbol "["
	methNames <- (try parserMethName) `sepBy` comma  
	(manyTill anyChar . try $ symbol "SchedInfo")    --EMPTY AREA NEEDED ? TODO
	scheduleInfos <- brackets $ (try parserSchedule) `sepBy`  comma --TODO Testing
	let mapScheduling = foldl (\map (x,y,z) -> Map.insert (x,y) z map) Map.empty $ concat scheduleInfos   

	
        manyTill anyChar . try $ symbol "meth" <* symbol "types" <* symbol "="
	typesMethods <- brackets $ (try.parens $ parseTripletTypes) `sepBy` comma  
	let finalList = process typesMethods methNames
   		
	return $ (Right (finalList, mapScheduling))
	where 	process l1 l2 = f $ List.zip l1 l2
	      	f [] = []	      
		f (((lArgsT,trigger,result),(mName,lArg)):q) = Fp{fpName = mName --TODO we forgot the trigger here.
				, fpType = sayMeMyType lArgsT result
				, fpArgs = zip lArg lArgsT }:(f q)
		sayMeMyType args res = case res of              --TODO : hardly defined before ... factorization
					Nothing -> Action  
					Just b  -> case args of
						[] -> Value0 b 
						_  -> Value b  --TODO : need a hack for actions value

-- method (cpuToHost, [])cpuToHost enable ((EN_cpuToHost,
-- [])) clocked_by (default_clock) reset_by (default_reset);,

parserMethName :: Parser (String,[String])
parserMethName = do
	symbol "method"
	option "" . parens . try . many $ noneOf [')']   --TODO Check if it"s correct
	nameMeth <- identifier 
	args <- option [] . parens $ (try . parens $ do{name<-identifier <* comma
					; brackets . many $ noneOf [']']
					; return name}) `sepBy` comma
	--Throw it away!
	
	option "" $ symbol "enable" 
	option "" . parens . parens . try . many $ noneOf [')']
	symbol "clocked_by" 
	option "" . parens . try . many $ noneOf [')']
	symbol "reset_by"
	option "" . parens . try . many $ noneOf [')']
 	semi 
	return (nameMeth, args)	 	    
	

-- Disgusting hacks here. ** Need refactoring **
-- /!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\
-- /!\ Lot of undefined behaviour are critic./!\
-- /!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\

parserSchedule :: Parser [(String, String, Conflict)]
parserSchedule = do
	r1 <- ((try.brackets.many $ noneOf [']']) <|> try identifier) 
	op <- identifier
	r2 <- ((try.brackets.many $ noneOf [']']) <|> identifier)
	return $ allCombines (inter r1) (inter r2) $ process op
	where 	inter l = S.split [','] $ filter (\x -> x /= ' ' && x /= '\n' ) l --DON'T LOOK AT THIS 
		allCombines [] l e = []
		allCombines (t:q) l e = allCombine t l e ++ allCombines q l e
		allCombine a [] e = []
		allCombine a (t:q) e = (a,t,e) : allCombine a q e	  
		process op = case lookup op l of
				Just a -> a
				Nothing -> trace "l454" $ undefined --Should not happen, ATS provided by BSC compiler
		l = [("C", C ),
			("CF", CF ),
			("SB", SB ),
			("SA", SA )]




parseTripletTypes :: Parser ([Integer], Maybe Integer, Maybe Integer)
parseTripletTypes = do
	first <- brackets $ (try bitParser) `sepBy` comma 
	comma 
	second <- maybeParser
	comma
	third <- maybeParser	
	return (first, second, third)

bitParser :: Parser Integer
bitParser = do
	symbol "Bit"
	val <- integer
	return $ val  

maybeParser :: Parser (Maybe Integer)
maybeParser = (try justP)<|>nothingP 

justP :: Parser (Maybe Integer)
justP = do
	symbol "Just"
	extract <- parens $ bitParser
	return $ Just extract


nothingP :: Parser (Maybe Integer)
nothingP = do
	symbol "Nothing"  --TODO : check
	return Nothing


--
--Formal parameters parser : use docs of BSV.
--

formalParametersParser :: Parser [Instance]
formalParametersParser = many $ try formalParameterParser

formalParameterParser :: Parser Instance
formalParameterParser = do
	name <- identifier <* colon
	par <- parens . many $  (try.parens.many $ noneOf [')']) <|> identifier  
	return Instance{instName = name
 		, instModule = "hack" --I don't remember why I thought it was smart to return Instance ... 
		, instArgs = par}

--
-- Tools
--

numberValue :: Integer -> String ->  Integer
numberValue n [a] = toInteger . digitToInt $ a 
numberValue n (t:q) =n*(numberValue n q) + (toInteger . digitToInt $  t)




